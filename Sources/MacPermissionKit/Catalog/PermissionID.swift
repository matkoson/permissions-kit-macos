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
    case speech
    case photos
    case photosAddOnly
    case contacts
    case calendars
    case reminders
    case mediaLibrary
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
}
