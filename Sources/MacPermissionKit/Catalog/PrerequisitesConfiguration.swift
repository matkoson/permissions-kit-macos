import Foundation

/// Host-facing configure-only knobs for the shared Prerequisites checklist + nav gate.
/// Every Matkoson GUI app should build a session from this type and avoid forking UI.
public struct PrerequisitesConfiguration: Sendable, Hashable {
    /// Required checklist members. Aggregate checklist is checked iff every member is granted.
    public var required: [PermissionID]
    /// When true, App Management is appended to `required` (routine-worker / control / automation).
    public var includesAppManagement: Bool
    /// Whether the first-run surface blocks other destinations until required grants succeed.
    public var blockUntilRequiredGranted: Bool

    public init(
        required: [PermissionID] = PermissionKind.prerequisitesDefaultRequired,
        includesAppManagement: Bool = false,
        blockUntilRequiredGranted: Bool = true
    ) {
        var ids = PermissionOrchestrator.uniqueIDs(required)
        if includesAppManagement, !ids.contains(.appManagement) {
            ids.append(.appManagement)
        }
        self.required = ids
        self.includesAppManagement = includesAppManagement
        self.blockUntilRequiredGranted = blockUntilRequiredGranted
    }

    /// Default matrix for every Matkoson GUI app (App Management off unless the host opts in).
    public static let standard = PrerequisitesConfiguration()

    /// routine-worker / control / automation hosts.
    public static let withAppManagement = PrerequisitesConfiguration(includesAppManagement: true)

    public var presentationPolicy: PermissionPresentationPolicy {
        PermissionPresentationPolicy(
            startupIDs: required,
            optionalIDs: [],
            blockUntilRequiredGranted: blockUntilRequiredGranted
        )
    }
}
