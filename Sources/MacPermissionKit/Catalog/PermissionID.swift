import Foundation

/// End-user TCC permission the host can probe, request, or send the user to Settings for.
public enum PermissionID: String, CaseIterable, Sendable, Codable, Hashable, Identifiable {
    case accessibility
    case screenRecording
    case inputMonitoring
    case microphone
    case camera
    case systemAudioCapture
    case fullDiskAccess
    case localNetwork
    case automation
    case automationShortcutsEvents
    case automationTestFlight
    case automationGoogleChrome
    case automationTextEdit
    case speech
    case photos
    case photosAddOnly
    case contacts
    case calendars
    case reminders
    case mediaLibrary
    case home
    case notifications
    case location
    case bluetooth
    case usb
    case desktopFolder
    case documentsFolder
    case downloadsFolder
    case removableVolumes
    case networkVolumes
    case developerTools
    case appManagement

    public var id: String { rawValue }

    /// AppleScript / Automation target name when this id is an Apple Events grant.
    public var automationTargetName: String? {
        switch self {
        case .automation: return "System Events"
        case .automationShortcutsEvents: return "Shortcuts Events"
        case .automationTestFlight: return "TestFlight"
        case .automationGoogleChrome: return "Google Chrome"
        case .automationTextEdit: return "TextEdit"
        default: return nil
        }
    }

    public var isAutomationTarget: Bool {
        automationTargetName != nil
    }
}
