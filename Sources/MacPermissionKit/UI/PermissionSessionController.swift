import AppKit
import Foundation
import Observation
import SwiftUI

/// Host-facing session that implements `PermissionStartupGlassShellSlot` and owns
/// a `PermissionOrchestrator`. Drive SwiftUI from this type only.
@MainActor
@Observable
public final class PermissionSessionController: PermissionStartupGlassShellSlot {
    public let orchestrator: PermissionOrchestrator

    public private(set) var isStartupPresented = false
    public private(set) var selectedID: PermissionID?
    public private(set) var deniedRecord: PermissionRecord?
    public private(set) var didFinishOnboarding = false

    public init(
        orchestrator: PermissionOrchestrator = PermissionOrchestrator(
            required: PermissionKind.prerequisitesDefaultRequired,
            policy: .standard
        )
    ) {
        self.orchestrator = orchestrator
        self.selectedID = orchestrator.nextRequired
    }

    public convenience init(
        required: [PermissionID] = PermissionKind.prerequisitesDefaultRequired,
        policy: PermissionPresentationPolicy = .standard
    ) {
        self.init(
            orchestrator: PermissionOrchestrator(required: required, policy: policy)
        )
    }

    public convenience init(configuration: PrerequisitesConfiguration) {
        self.init(
            orchestrator: PermissionOrchestrator(
                required: configuration.required,
                policy: configuration.presentationPolicy
            )
        )
    }

    // MARK: - Derived

    public var records: [PermissionRecord] {
        let ids = orchestrator.policy.startupIDs.isEmpty
            ? PermissionID.allCases
            : orchestrator.policy.startupIDs
        return ids.map { orchestrator.snapshot.record(for: $0) }
    }

    public var pending: PermissionID? { orchestrator.pending }

    public var focusedID: PermissionID? {
        orchestrator.nextRequired ?? selectedID
    }

    public var focusedKind: PermissionKind? {
        focusedID.map { PermissionKind.kind(for: $0) }
    }

    public var progress: Double {
        let blocking = orchestrator.required.filter { !orchestrator.policy.optionalIDs.contains($0) }
        guard blocking.isEmpty == false else { return 1 }
        return Double(orchestrator.requiredGrantedCount) / Double(blocking.count)
    }

    public var canDismiss: Bool {
        if didFinishOnboarding { return true }
        if orchestrator.policy.blockUntilRequiredGranted == false { return true }
        return orchestrator.allRequiredSatisfied
    }

    // MARK: - PermissionStartupGlassShellSlot

    public func refreshFromWindowKey() {
        orchestrator.refresh()
        if let next = orchestrator.nextRequired {
            selectedID = next
        }
    }

    /// Update selection from an already-refreshed orchestrator (e.g. after `gate.refresh()`).
    /// Does not re-probe permissions.
    public func syncSelectionFromOrchestrator() {
        if let next = orchestrator.nextRequired {
            selectedID = next
        }
    }

    public func advance() async {
        let result = await orchestrator.advanceStartup()
        apply(result: result)
    }

    public func finishOnboarding() {
        didFinishOnboarding = true
        isStartupPresented = false
    }

    // MARK: - Actions

    public func presentStartup() {
        orchestrator.refresh()
        selectedID = orchestrator.nextRequired ?? orchestrator.policy.startupIDs.first
        isStartupPresented = true
    }

    public func select(_ id: PermissionID) {
        selectedID = id
    }

    public func request(_ id: PermissionID) async {
        select(id)
        let result = await orchestrator.request(id)
        apply(result: result)
    }

    public func openSettings(for id: PermissionID) async {
        _ = await orchestrator.openSettings(id)
    }

    /// After Settings for kinds with no public probe (Home, Developer Tools), host confirms grant.
    public func confirmSettingsGrant(_ id: PermissionID) {
        do {
            try orchestrator.confirmSettingsGrant(id)
            selectedID = orchestrator.nextRequired ?? id
            if canDismiss { finishOnboarding() }
        } catch {
            // Leave UI unchanged when id is not settings-only.
        }
    }

    public func openSettingsForSelection() async {
        guard let id = deniedRecord?.id ?? selectedID ?? focusedID else { return }
        await openSettings(for: id)
    }

    public func skipCurrent() {
        guard let id = deniedRecord?.id ?? selectedID ?? focusedID else { return }
        do {
            try orchestrator.skip(id)
            deniedRecord = nil
            selectedID = orchestrator.nextRequired
            if canDismiss {
                finishOnboarding()
            }
        } catch {
            // Non-optional permissions cannot be skipped; leave UI state unchanged.
        }
    }

    public func quitNow() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Private

    private func apply(result: PermissionRequestResult?) {
        guard let result else {
            if canDismiss { finishOnboarding() }
            return
        }
        if result.record.authorization == .denied || result.record.authorization == .restricted {
            deniedRecord = result.record
        } else {
            deniedRecord = nil
        }
        selectedID = orchestrator.nextRequired ?? result.record.id
        if canDismiss {
            finishOnboarding()
        }
    }
}

/// Row adapter that satisfies `PermissionRowSlot`.
@MainActor
public final class PermissionRowController: PermissionRowSlot {
    public let permissionID: PermissionID
    private let session: PermissionSessionController

    public init(permissionID: PermissionID, session: PermissionSessionController) {
        self.permissionID = permissionID
        self.session = session
    }

    public func request() async {
        await session.request(permissionID)
    }

    public func openSettings() async {
        await session.openSettings(for: permissionID)
    }
}
