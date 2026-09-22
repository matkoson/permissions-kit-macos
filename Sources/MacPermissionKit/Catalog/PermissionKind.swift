import Foundation

public enum PermissionFamily: String, Sendable, Codable, Hashable {
    case privacy
    case automation
    case files
    case hardware
    case network
    case developer
}

/// How the engine asks. The host must not invent a second prompt on top of these.
public enum PermissionPromptKind: String, Sendable, Codable, Hashable {
    /// In-process system API that can present a TCC dialog.
    case systemPrompt
    /// A deliberate side effect (AppleScript or a LAN packet). Status may stay unknown.
    case sideEffectNudge
    /// No honest in-process grant API. Open Settings and wait for the user to return.
    case settingsOnly
    /// Reserved for permissions whose state cannot be observed or requested.
    case opaque
}

public enum PermissionRelaunch: String, Sendable, Codable, Hashable {
    case none
    case recommendedAfterGrant
    case requiredAfterGrant
}

/// Static metadata for one PermissionID. The host copies usage keys and entitlements into its own target.
public struct PermissionKind: Sendable, Hashable, Codable {
    public let id: PermissionID
    public let family: PermissionFamily
    public let systemSettingsTitle: String
    public let purpose: String
    public let promptKind: PermissionPromptKind
    public let relaunch: PermissionRelaunch
    public let dragIntoListRequired: Bool
    public let usageDescriptionKeys: [String]
    public let sandboxEntitlements: [String]
    /// Service name passed to the TCC reset tool. Nil when the service name is not public and stable.
    public let tccService: String?
    /// Anchor appended to the Privacy settings URL. Nil opens the pane root.
    public let settingsAnchor: String?

    public var primarySettingsURL: URL? {
        Self.settingsURL(schemeAnchor: "com.apple.settings.PrivacySecurity.extension", anchor: settingsAnchor)
    }

    public var fallbackSettingsURL: URL? {
        Self.settingsURL(schemeAnchor: "com.apple.preference.security", anchor: settingsAnchor)
    }

    public static func kind(for id: PermissionID) -> PermissionKind {
        guard let kind = byID[id] else {
            preconditionFailure("Permission catalog is missing \(id.rawValue)")
        }
        return kind
    }

    public static let all: [PermissionKind] = catalog

    /// First-run order. Optional members are chosen by PermissionPresentationPolicy, not by this list.
    public static let startupDefaultOrder: [PermissionID] = [
        .accessibility,
        .screenRecording,
        .inputMonitoring,
        .microphone,
        .camera,
        .systemAudioCapture,
        .fullDiskAccess,
        .localNetwork,
        .automation,
    ]

    private static let byID: [PermissionID: PermissionKind] = {
        var map: [PermissionID: PermissionKind] = [:]
        for kind in catalog {
            map[kind.id] = kind
        }
        return map
    }()

    private static func settingsURL(schemeAnchor: String, anchor: String?) -> URL? {
        if let anchor, !anchor.isEmpty {
            return URL(string: "x-apple.systempreferences:\(schemeAnchor)?\(anchor)")
        }
        return URL(string: "x-apple.systempreferences:\(schemeAnchor)")
    }
}

private let catalog: [PermissionKind] = [
    kind(.accessibility, family: .privacy, title: "Accessibility", purpose: "Post and observe UI events for automation and computer-use.", prompt: .systemPrompt, relaunch: .recommendedAfterGrant, drag: true, usage: [], entitlements: [], tcc: "kTCCServiceAccessibility", anchor: "Privacy_Accessibility"),
    kind(.screenRecording, family: .privacy, title: "Screen Recording", purpose: "Read screen pixels. Preflight and request only; never open the share picker to probe.", prompt: .systemPrompt, relaunch: .requiredAfterGrant, drag: true, usage: ["NSScreenCaptureUsageDescription"], entitlements: [], tcc: "kTCCServiceScreenCapture", anchor: "Privacy_ScreenCapture"),
    kind(.inputMonitoring, family: .privacy, title: "Input Monitoring", purpose: "Listen to keyboard and pointer events.", prompt: .systemPrompt, relaunch: .requiredAfterGrant, drag: true, usage: [], entitlements: [], tcc: "kTCCServiceListenEvent", anchor: "Privacy_ListenEvent"),
    kind(.microphone, family: .hardware, title: "Microphone", purpose: "Capture microphone audio.", prompt: .systemPrompt, relaunch: .none, drag: false, usage: ["NSMicrophoneUsageDescription"], entitlements: ["com.apple.security.device.audio-input"], tcc: "kTCCServiceMicrophone", anchor: "Privacy_Microphone"),
    kind(.camera, family: .hardware, title: "Camera", purpose: "Capture the camera.", prompt: .systemPrompt, relaunch: .none, drag: false, usage: ["NSCameraUsageDescription"], entitlements: ["com.apple.security.device.camera"], tcc: "kTCCServiceCamera", anchor: "Privacy_Camera"),
    kind(.systemAudioCapture, family: .privacy, title: "System Audio Capture", purpose: "Capture system audio. Same Settings list as Screen Recording. No in-process grant API.", prompt: .settingsOnly, relaunch: .recommendedAfterGrant, drag: true, usage: ["NSAudioCaptureUsageDescription"], entitlements: [], tcc: nil, anchor: "Privacy_ScreenCapture"),
    kind(.fullDiskAccess, family: .files, title: "Full Disk Access", purpose: "Read protected user files. Request only opens Settings. A later refresh may observe access.", prompt: .settingsOnly, relaunch: .requiredAfterGrant, drag: true, usage: [], entitlements: [], tcc: "kTCCServiceSystemPolicyAllFiles", anchor: "Privacy_AllFiles"),
    kind(.localNetwork, family: .network, title: "Local Network", purpose: "Talk to devices on the local network. A UDP nudge may surface the prompt. Status stays unknown.", prompt: .sideEffectNudge, relaunch: .none, drag: false, usage: ["NSLocalNetworkUsageDescription"], entitlements: ["com.apple.security.network.client"], tcc: nil, anchor: "Privacy_LocalNetwork"),
    kind(.automation, family: .automation, title: "Automation", purpose: "Send Apple events to System Events so the Automation prompt can appear.", prompt: .sideEffectNudge, relaunch: .none, drag: false, usage: ["NSAppleEventsUsageDescription"], entitlements: ["com.apple.security.automation.apple-events"], tcc: "kTCCServiceAppleEvents", anchor: "Privacy_Automation"),
    kind(.speech, family: .privacy, title: "Speech Recognition", purpose: "Use speech recognition.", prompt: .systemPrompt, relaunch: .none, drag: false, usage: ["NSSpeechRecognitionUsageDescription"], entitlements: [], tcc: "kTCCServiceSpeechRecognition", anchor: "Privacy_SpeechRecognition"),
    kind(.photos, family: .privacy, title: "Photos", purpose: "Read the photo library.", prompt: .systemPrompt, relaunch: .none, drag: false, usage: ["NSPhotoLibraryUsageDescription"], entitlements: ["com.apple.security.personal-information.photos-library"], tcc: "kTCCServicePhotos", anchor: "Privacy_Photos"),
    kind(.photosAddOnly, family: .privacy, title: "Photos (Add Only)", purpose: "Add images to Photos without reading the library.", prompt: .systemPrompt, relaunch: .none, drag: false, usage: ["NSPhotoLibraryAddUsageDescription"], entitlements: ["com.apple.security.personal-information.photos-library"], tcc: "kTCCServicePhotosAdd", anchor: "Privacy_Photos"),
    kind(.contacts, family: .privacy, title: "Contacts", purpose: "Read contacts.", prompt: .systemPrompt, relaunch: .none, drag: false, usage: ["NSContactsUsageDescription"], entitlements: ["com.apple.security.personal-information.addressbook"], tcc: "kTCCServiceAddressBook", anchor: "Privacy_Contacts"),
    kind(.calendars, family: .privacy, title: "Calendars", purpose: "Read and write calendars.", prompt: .systemPrompt, relaunch: .none, drag: false, usage: ["NSCalendarsUsageDescription", "NSCalendarsFullAccessUsageDescription"], entitlements: ["com.apple.security.personal-information.calendars"], tcc: "kTCCServiceCalendar", anchor: "Privacy_Calendars"),
    kind(.reminders, family: .privacy, title: "Reminders", purpose: "Read and write reminders.", prompt: .systemPrompt, relaunch: .none, drag: false, usage: ["NSRemindersUsageDescription", "NSRemindersFullAccessUsageDescription"], entitlements: ["com.apple.security.personal-information.calendars"], tcc: "kTCCServiceReminders", anchor: "Privacy_Reminders"),
    kind(.mediaLibrary, family: .privacy, title: "Media Library", purpose: "Read the Music library. No in-process grant API is called; request opens Settings.", prompt: .settingsOnly, relaunch: .none, drag: false, usage: ["NSAppleMusicUsageDescription"], entitlements: [], tcc: "kTCCServiceMediaLibrary", anchor: "Privacy_Media"),
    kind(.notifications, family: .privacy, title: "Notifications", purpose: "Post notifications.", prompt: .systemPrompt, relaunch: .none, drag: false, usage: [], entitlements: [], tcc: nil, anchor: nil),
    kind(.location, family: .privacy, title: "Location Services", purpose: "Read this Mac location.", prompt: .systemPrompt, relaunch: .none, drag: false, usage: ["NSLocationUsageDescription"], entitlements: ["com.apple.security.personal-information.location"], tcc: "kTCCServiceLocation", anchor: "Privacy_LocationServices"),
    kind(.bluetooth, family: .hardware, title: "Bluetooth", purpose: "Use Bluetooth.", prompt: .systemPrompt, relaunch: .none, drag: false, usage: ["NSBluetoothAlwaysUsageDescription"], entitlements: ["com.apple.security.device.bluetooth"], tcc: "kTCCServiceBluetoothAlways", anchor: "Privacy_Bluetooth"),
    kind(.usb, family: .hardware, title: "USB Accessories", purpose: "Access USB devices. Settings only; the TCC service name is not guessed.", prompt: .settingsOnly, relaunch: .none, drag: false, usage: [], entitlements: [], tcc: nil, anchor: nil),
    kind(.desktopFolder, family: .files, title: "Desktop Folder", purpose: "Read the Desktop folder.", prompt: .settingsOnly, relaunch: .none, drag: false, usage: [], entitlements: ["com.apple.security.files.user-selected.read-write"], tcc: "kTCCServiceSystemPolicyDesktopFolder", anchor: "Privacy_FilesAndFolders"),
    kind(.documentsFolder, family: .files, title: "Documents Folder", purpose: "Read the Documents folder.", prompt: .settingsOnly, relaunch: .none, drag: false, usage: [], entitlements: ["com.apple.security.files.user-selected.read-write"], tcc: "kTCCServiceSystemPolicyDocumentsFolder", anchor: "Privacy_FilesAndFolders"),
    kind(.downloadsFolder, family: .files, title: "Downloads Folder", purpose: "Read the Downloads folder.", prompt: .settingsOnly, relaunch: .none, drag: false, usage: [], entitlements: ["com.apple.security.files.downloads.read-write"], tcc: "kTCCServiceSystemPolicyDownloadsFolder", anchor: "Privacy_FilesAndFolders"),
    kind(.removableVolumes, family: .files, title: "Removable Volumes", purpose: "Read removable volumes.", prompt: .settingsOnly, relaunch: .none, drag: false, usage: [], entitlements: [], tcc: "kTCCServiceSystemPolicyRemovableVolumes", anchor: "Privacy_FilesAndFolders"),
    kind(.networkVolumes, family: .files, title: "Network Volumes", purpose: "Read network volumes.", prompt: .settingsOnly, relaunch: .none, drag: false, usage: [], entitlements: ["com.apple.security.network.client"], tcc: "kTCCServiceSystemPolicyNetworkVolumes", anchor: "Privacy_FilesAndFolders"),
    kind(.developerTools, family: .developer, title: "Developer Tools", purpose: "Run Apple developer tools that need the Developer Tools privacy switch.", prompt: .settingsOnly, relaunch: .none, drag: true, usage: [], entitlements: [], tcc: "kTCCServiceDeveloperTool", anchor: "Privacy_DevTools"),
    kind(.appManagement, family: .developer, title: "App Management", purpose: "Update or modify other apps. No stable public TCC service is called.", prompt: .settingsOnly, relaunch: .recommendedAfterGrant, drag: true, usage: [], entitlements: [], tcc: nil, anchor: "Privacy_AppBundles"),
]

private func kind(
    _ id: PermissionID,
    family: PermissionFamily,
    title: String,
    purpose: String,
    prompt: PermissionPromptKind,
    relaunch: PermissionRelaunch,
    drag: Bool,
    usage: [String],
    entitlements: [String],
    tcc: String?,
    anchor: String?
) -> PermissionKind {
    PermissionKind(
        id: id,
        family: family,
        systemSettingsTitle: title,
        purpose: purpose,
        promptKind: prompt,
        relaunch: relaunch,
        dragIntoListRequired: drag,
        usageDescriptionKeys: usage,
        sandboxEntitlements: entitlements,
        tccService: tcc,
        settingsAnchor: anchor
    )
}
