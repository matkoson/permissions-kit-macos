import Foundation

public enum PermissionAuthorization: String, Sendable, Codable, Hashable, CaseIterable {
    case notDetermined
    case granted
    case denied
    case restricted
    case unknown
    case unsupported
}

public struct PermissionRecord: Sendable, Hashable, Codable, Identifiable {
    public let id: PermissionID
    public var authorization: PermissionAuthorization

    public init(id: PermissionID, authorization: PermissionAuthorization) {
        self.id = id
        self.authorization = authorization
    }
}

public struct PermissionSnapshot: Sendable, Hashable, Codable {
    public let records: [PermissionRecord]

    public init(records: [PermissionRecord]) {
        self.records = records
    }

    public func authorization(for id: PermissionID) -> PermissionAuthorization {
        records.first { $0.id == id }?.authorization ?? .unsupported
    }

    public func record(for id: PermissionID) -> PermissionRecord {
        records.first { $0.id == id } ?? PermissionRecord(id: id, authorization: .unsupported)
    }

    public var grantedCount: Int {
        records.reduce(into: 0) { count, record in
            if record.authorization == .granted {
                count += 1
            }
        }
    }

    public func grantedCount(among ids: [PermissionID]) -> Int {
        ids.reduce(into: 0) { count, id in
            if authorization(for: id) == .granted {
                count += 1
            }
        }
    }
}

public struct PermissionRequestResult: Sendable, Hashable, Codable {
    public var record: PermissionRecord
    public var settingsOpened: Bool
    public var promptPresented: Bool
    public var relaunchRequired: Bool

    public init(
        record: PermissionRecord,
        settingsOpened: Bool,
        promptPresented: Bool,
        relaunchRequired: Bool
    ) {
        self.record = record
        self.settingsOpened = settingsOpened
        self.promptPresented = promptPresented
        self.relaunchRequired = relaunchRequired
    }
}

public struct PermissionBackendEvent: Sendable, Hashable {
    public var authorization: PermissionAuthorization
    public var promptPresented: Bool
    public var settingsOpened: Bool

    public init(
        authorization: PermissionAuthorization,
        promptPresented: Bool,
        settingsOpened: Bool
    ) {
        self.authorization = authorization
        self.promptPresented = promptPresented
        self.settingsOpened = settingsOpened
    }
}

public enum PermissionKitError: Error, Equatable, Sendable, CustomStringConvertible {
    case resetUnsupported(PermissionID)
    case resetFailed(PermissionID, Int32)
    case skipNotAllowed(PermissionID)
    case backend(String)
    case command(String)

    public var description: String {
        switch self {
        case .resetUnsupported(let id):
            return "Reset is not available for \(id.rawValue) because it has no stable TCC service name."
        case .resetFailed(let id, let status):
            return "Reset failed for \(id.rawValue) with status \(status)."
        case .skipNotAllowed(let id):
            return "\(id.rawValue) is not optional and cannot be skipped."
        case .backend(let message):
            return message
        case .command(let message):
            return message
        }
    }
}
