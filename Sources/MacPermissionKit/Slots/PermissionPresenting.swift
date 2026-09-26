import Foundation

/// What the host may skip, and whether first launch stays up until the blocking set is granted.
public struct PermissionPresentationPolicy: Sendable, Hashable {
    public var startupIDs: [PermissionID]
    public var optionalIDs: Set<PermissionID>
    public var blockUntilRequiredGranted: Bool

    public init(
        startupIDs: [PermissionID] = PermissionKind.prerequisitesDefaultRequired,
        optionalIDs: Set<PermissionID> = [],
        blockUntilRequiredGranted: Bool = true
    ) {
        self.startupIDs = startupIDs
        self.optionalIDs = optionalIDs
        self.blockUntilRequiredGranted = blockUntilRequiredGranted
    }

    /// Prerequisites checklist defaults (no optional skips).
    public static let standard = PermissionPresentationPolicy()

    /// Legacy optional set from the pre-Prerequisites wizard era.
    public static let legacyStartup = PermissionPresentationPolicy(
        startupIDs: PermissionKind.startupDefaultOrder,
        optionalIDs: [
            .camera,
            .systemAudioCapture,
            .automation,
            .localNetwork,
        ],
        blockUntilRequiredGranted: true
    )

    public var blockingIDs: [PermissionID] {
        startupIDs.filter { !optionalIDs.contains($0) }
    }
}

/// Names of the presentation slots. Concrete SwiftUI surfaces live under `UI/`.
public enum PermissionSlot: String, CaseIterable, Sendable, Codable {
    case startupGlassShell = "SLOT_StartupGlassShell"
    case prerequisitesChecklist = "SLOT_PrerequisitesChecklist"
    case prerequisitesSplash = "SLOT_PrerequisitesSplash"
    case permissionList = "SLOT_PermissionList"
    case permissionRow = "SLOT_PermissionRow"
    case systemPromptPending = "SLOT_SystemPromptPending"
    case openSettingsCTA = "SLOT_OpenSettingsCTA"
    case dragIntoListHint = "SLOT_DragIntoListHint"
    case quitAndRelaunch = "SLOT_QuitAndRelaunch"
    case deniedRecovery = "SLOT_DeniedRecovery"
    case completion = "SLOT_Completion"
}

public enum PermissionSlotCopy {
    public static func dragIntoListHint(bundleName: String, id: PermissionID) -> String {
        let title = PermissionKind.kind(for: id).systemSettingsTitle
        return "Drag \(bundleName) into the \(title) list, then return here."
    }

    public static func waitingForPrompt(id: PermissionID) -> String {
        let title = PermissionKind.kind(for: id).systemSettingsTitle
        return "Waiting for the \(title) permission dialog."
    }

    public static func primaryButtonTitle(id: PermissionID) -> String {
        switch PermissionKind.kind(for: id).promptKind {
        case .systemPrompt:
            return "Request"
        case .sideEffectNudge:
            return "Trigger Prompt"
        case .settingsOnly, .opaque:
            return "Open Settings"
        }
    }

    public static func showsDragHint(id: PermissionID) -> Bool {
        PermissionKind.kind(for: id).dragIntoListRequired
    }
}

/// Host implements this for the first-run window. The backend does not draw it.
@MainActor
public protocol PermissionStartupGlassShellSlot: AnyObject {
    var canDismiss: Bool { get }
    func refreshFromWindowKey()
    func advance() async
    func finishOnboarding()
}

/// Host implements this for one Settings row.
@MainActor
public protocol PermissionRowSlot: AnyObject {
    var permissionID: PermissionID { get }
    func request() async
    func openSettings() async
}
