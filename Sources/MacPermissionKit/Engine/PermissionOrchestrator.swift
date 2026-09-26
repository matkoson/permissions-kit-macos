import Foundation
import Observation

/// One process's TCC session. The host binds UI to the published fields and does not cache status.
@MainActor
@Observable
public final class PermissionOrchestrator {
    public let required: [PermissionID]
    public let policy: PermissionPresentationPolicy
    public private(set) var snapshot: PermissionSnapshot
    public private(set) var pending: PermissionID?
    public private(set) var lastResult: PermissionRequestResult?
    public private(set) var relaunchRequired: Bool
    public private(set) var skipped: Set<PermissionID>

    private let backend: any PermissionBackend
    private let bundleIdentifier: String?
    private var operationInFlight = false
    private var operationWaiters: [CheckedContinuation<Void, Never>] = []

    public convenience init(
        required: [PermissionID],
        policy: PermissionPresentationPolicy = .standard,
        bundleIdentifier: String? = Bundle.main.bundleIdentifier
    ) {
        self.init(
            required: required,
            policy: policy,
            backend: SystemPermissionBackend(),
            bundleIdentifier: bundleIdentifier
        )
    }

    init(
        required: [PermissionID],
        policy: PermissionPresentationPolicy,
        backend: any PermissionBackend,
        bundleIdentifier: String?
    ) {
        self.required = Self.uniqueIDs(required)
        self.policy = policy
        self.backend = backend
        self.bundleIdentifier = bundleIdentifier
        self.snapshot = PermissionSnapshot(records: [])
        self.pending = nil
        self.lastResult = nil
        self.relaunchRequired = false
        self.skipped = []
        self.snapshot = Self.makeSnapshot(backend: backend)
    }

    public var nextRequired: PermissionID? {
        required.first { id in
            snapshot.authorization(for: id) != .granted && !skipped.contains(id)
        }
    }

    /// Blocking startup permissions are granted (or unsupported / not installed). Optional ids do not hold this open.
    public var allRequiredSatisfied: Bool {
        required.allSatisfy { id in
            if policy.optionalIDs.contains(id) { return true }
            let authorization = snapshot.authorization(for: id)
            return authorization == .granted || authorization == .unsupported
        }
    }

    public var requiredGrantedCount: Int {
        snapshot.grantedCount(among: required.filter { !policy.optionalIDs.contains($0) })
    }

    public func refresh() {
        let previous = snapshot
        var next = Self.makeSnapshot(backend: backend)
        var records = next.records
        for index in records.indices {
            let probed = records[index].authorization
            let prior = previous.authorization(for: records[index].id)
            if probed == .unknown, prior != .unknown, prior != .unsupported {
                records[index].authorization = prior
            }
        }
        next = PermissionSnapshot(records: records)
        for id in PermissionID.allCases {
            let kind = PermissionKind.kind(for: id)
            guard kind.relaunch != .none else { continue }
            let was = previous.authorization(for: id)
            let now = next.authorization(for: id)
            if was != .unsupported && now == .granted && was != .granted {
                relaunchRequired = true
            }
        }
        snapshot = next
    }

    /// Requests the first required id that is not granted and not skipped. One id per call.
    @discardableResult
    public func advanceStartup() async -> PermissionRequestResult? {
        guard let id = nextRequired else { return nil }
        return await request(id)
    }

    @discardableResult
    public func request(_ id: PermissionID) async -> PermissionRequestResult {
        await acquireOperation()
        defer { releaseOperation() }
        pending = id
        defer { pending = nil }
        let event = await backend.request(id)
        let kind = PermissionKind.kind(for: id)
        let reported: PermissionAuthorization
        switch kind.promptKind {
        case .settingsOnly, .opaque:
            reported = .unknown
            replaceAuthorization(id, with: backend.probe(id))
        case .sideEffectNudge where id == .localNetwork:
            reported = .unknown
            replaceAuthorization(id, with: .unknown)
        default:
            reported = event.authorization
            replaceAuthorization(id, with: event.authorization)
        }
        let relaunchNow = reported == .granted && kind.relaunch != .none
        if relaunchNow {
            relaunchRequired = true
        }
        let result = PermissionRequestResult(
            record: PermissionRecord(id: id, authorization: reported),
            settingsOpened: event.settingsOpened,
            promptPresented: event.promptPresented,
            relaunchRequired: relaunchNow
        )
        lastResult = result
        return result
    }

    @discardableResult
    public func openSettings(_ id: PermissionID) async -> PermissionRequestResult {
        await acquireOperation()
        defer { releaseOperation() }
        pending = id
        defer { pending = nil }
        let opened = await backend.openSettings(for: id)
        replaceAuthorization(id, with: backend.probe(id))
        let result = PermissionRequestResult(
            record: snapshot.record(for: id),
            settingsOpened: opened,
            promptPresented: false,
            relaunchRequired: false
        )
        lastResult = result
        return result
    }

    public func reset(_ id: PermissionID) throws {
        guard let bundleIdentifier, bundleIdentifier.isEmpty == false else {
            throw PermissionKitError.bundleIdentifierRequired
        }
        if operationInFlight {
            throw PermissionKitError.operationInFlight
        }
        try backend.reset(id, bundleIdentifier: bundleIdentifier)
        refresh()
    }

    public func skip(_ id: PermissionID) throws {
        guard policy.optionalIDs.contains(id) else {
            throw PermissionKitError.skipNotAllowed(id)
        }
        skipped.insert(id)
    }

    /// For settings-only kinds with no public probe (Home, Developer Tools): host/UI confirms after Settings.
    public func confirmSettingsGrant(_ id: PermissionID) throws {
        let kind = PermissionKind.kind(for: id)
        guard kind.promptKind == .settingsOnly || kind.promptKind == .opaque else {
            throw PermissionKitError.command("confirmSettingsGrant is only for settings-only permissions.")
        }
        replaceAuthorization(id, with: .granted)
    }

    private func acquireOperation() async {
        if operationInFlight {
            await withCheckedContinuation { continuation in
                operationWaiters.append(continuation)
            }
            return
        }
        operationInFlight = true
    }

    private func releaseOperation() {
        if operationWaiters.isEmpty {
            operationInFlight = false
        } else {
            operationWaiters.removeFirst().resume()
        }
    }

    private func replaceAuthorization(_ id: PermissionID, with authorization: PermissionAuthorization) {
        var records = snapshot.records
        if let index = records.firstIndex(where: { $0.id == id }) {
            records[index].authorization = authorization
        } else {
            records.append(PermissionRecord(id: id, authorization: authorization))
        }
        snapshot = PermissionSnapshot(records: records)
    }

    private static func makeSnapshot(backend: any PermissionBackend) -> PermissionSnapshot {
        PermissionSnapshot(
            records: PermissionID.allCases.map { id in
                PermissionRecord(id: id, authorization: backend.probe(id))
            }
        )
    }

    nonisolated public static func uniqueIDs(_ ids: [PermissionID]) -> [PermissionID] {
        var seen: Set<PermissionID> = []
        var ordered: [PermissionID] = []
        for id in ids where seen.insert(id).inserted {
            ordered.append(id)
        }
        return ordered
    }
}
