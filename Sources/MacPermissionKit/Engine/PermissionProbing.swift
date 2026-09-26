import Foundation

protocol PermissionBackend: Sendable {
    func probe(_ id: PermissionID) -> PermissionAuthorization
    func request(_ id: PermissionID) async -> PermissionBackendEvent
    func openSettings(for id: PermissionID) async -> Bool
    func reset(_ id: PermissionID, bundleIdentifier: String?) throws
}

struct PermissionPrimitives: Sendable {
    var accessibilityTrusted: @Sendable (Bool) -> Bool
    var screenPreflight: @Sendable () -> Bool
    var screenRequest: @Sendable () -> Bool
    var inputStatus: @Sendable () -> PermissionAuthorization
    var inputRequest: @Sendable () -> Bool
    var captureStatus: @Sendable (Bool) -> PermissionAuthorization
    var captureRequest: @Sendable (Bool) async -> Bool
    var speechStatus: @Sendable () -> PermissionAuthorization
    var speechRequest: @Sendable () async -> PermissionAuthorization
    var photosStatus: @Sendable (Bool) -> PermissionAuthorization
    var photosRequest: @Sendable (Bool) async -> PermissionAuthorization
    var contactsStatus: @Sendable () -> PermissionAuthorization
    var contactsRequest: @Sendable () async -> PermissionAuthorization
    var eventsStatus: @Sendable (Bool) -> PermissionAuthorization
    var eventsRequest: @Sendable (Bool) async -> PermissionAuthorization
    var mediaStatus: @Sendable () -> PermissionAuthorization
    var mediaRequest: @Sendable () async -> PermissionAuthorization
    var notificationStatus: @Sendable () async -> PermissionAuthorization
    var notificationRequest: @Sendable () async -> PermissionAuthorization
    var locationStatus: @Sendable () -> PermissionAuthorization
    var locationRequest: @Sendable () async -> PermissionAuthorization
    var bluetoothStatus: @Sendable () -> PermissionAuthorization
    var bluetoothRequest: @Sendable () async -> PermissionAuthorization
    var homeStatus: @Sendable () -> PermissionAuthorization
    var homeRequest: @Sendable () async -> PermissionAuthorization
    var developerToolsStatus: @Sendable () -> PermissionAuthorization
    /// Non-prompting Automation probe for a target application name.
    var automationStatus: @Sendable (String) -> PermissionAuthorization
    /// May present the Automation TCC prompt for a target application name.
    var automationRequest: @Sendable (String) -> PermissionAuthorization
    var localNetworkNudge: @Sendable () -> Void
    var fullDiskReadable: @Sendable () -> Bool
    var openURL: @Sendable (URL) async -> Bool
    var run: @Sendable ([String]) throws -> Int32

    static let live = LivePermissionCalls.primitives
}

enum ProcessSpawner {
    static func run(_ arguments: [String]) throws -> Int32 {
        guard let executable = arguments.first, !executable.isEmpty else {
            throw PermissionKitError.backend("empty command")
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = Array(arguments.dropFirst())
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }
}

enum PermissionDecider {
    static func probe(_ id: PermissionID, primitives: PermissionPrimitives) -> PermissionAuthorization {
        switch id {
        case .accessibility:
            return primitives.accessibilityTrusted(false) ? .granted : .denied
        case .screenRecording:
            return primitives.screenPreflight() ? .granted : .denied
        case .inputMonitoring:
            return primitives.inputStatus()
        case .microphone:
            return primitives.captureStatus(false)
        case .camera:
            return primitives.captureStatus(true)
        case .speech:
            return primitives.speechStatus()
        case .photos:
            return primitives.photosStatus(false)
        case .photosAddOnly:
            return primitives.photosStatus(true)
        case .contacts:
            return primitives.contactsStatus()
        case .calendars:
            return primitives.eventsStatus(false)
        case .reminders:
            return primitives.eventsStatus(true)
        case .mediaLibrary:
            return primitives.mediaStatus()
        case .notifications:
            return .unknown
        case .location:
            return primitives.locationStatus()
        case .bluetooth:
            return primitives.bluetoothStatus()
        case .home:
            return primitives.homeStatus()
        case .fullDiskAccess:
            return primitives.fullDiskReadable() ? .granted : .denied
        case .developerTools:
            return primitives.developerToolsStatus()
        case .automation, .automationShortcutsEvents, .automationTestFlight,
             .automationGoogleChrome, .automationTextEdit:
            if let target = id.automationTargetName {
                return primitives.automationStatus(target)
            }
            return .unknown
        case .systemAudioCapture, .localNetwork, .usb, .desktopFolder, .documentsFolder,
             .downloadsFolder, .removableVolumes, .networkVolumes, .appManagement:
            return .unknown
        }
    }

    static func request(_ id: PermissionID, primitives: PermissionPrimitives) async -> PermissionBackendEvent {
        let kind = PermissionKind.kind(for: id)
        switch kind.promptKind {
        case .settingsOnly, .opaque:
            let opened = await openSettings(id, primitives: primitives)
            return PermissionBackendEvent(authorization: .unknown, promptPresented: false, settingsOpened: opened)
        case .sideEffectNudge:
            return await nudge(id, primitives: primitives)
        case .systemPrompt:
            return await prompt(id, primitives: primitives)
        }
    }

    static func openSettings(_ id: PermissionID, primitives: PermissionPrimitives) async -> Bool {
        let kind = PermissionKind.kind(for: id)
        if let primary = kind.primarySettingsURL, await primitives.openURL(primary) {
            return true
        }
        if let fallback = kind.fallbackSettingsURL, fallback != kind.primarySettingsURL {
            return await primitives.openURL(fallback)
        }
        return false
    }

    static func reset(
        _ id: PermissionID,
        bundleIdentifier: String?,
        primitives: PermissionPrimitives
    ) throws {
        guard let service = PermissionKind.kind(for: id).tccService else {
            throw PermissionKitError.resetUnsupported(id)
        }
        var arguments = ["/usr/bin/tccutil", "reset", service]
        if let bundleIdentifier, !bundleIdentifier.isEmpty {
            arguments.append(bundleIdentifier)
        }
        let status = try primitives.run(arguments)
        guard status == 0 else {
            throw PermissionKitError.resetFailed(id, status)
        }
    }

    private static func nudge(_ id: PermissionID, primitives: PermissionPrimitives) async -> PermissionBackendEvent {
        switch id {
        case .localNetwork:
            primitives.localNetworkNudge()
            return PermissionBackendEvent(authorization: .unknown, promptPresented: true, settingsOpened: false)
        case .automation, .automationShortcutsEvents, .automationTestFlight,
             .automationGoogleChrome, .automationTextEdit:
            let target = id.automationTargetName ?? "System Events"
            let authorization = primitives.automationRequest(target)
            var opened = false
            if authorization == .denied || authorization == .restricted {
                opened = await openSettings(id, primitives: primitives)
            }
            return PermissionBackendEvent(
                authorization: authorization,
                promptPresented: true,
                settingsOpened: opened
            )
        default:
            let opened = await openSettings(id, primitives: primitives)
            return PermissionBackendEvent(authorization: .unknown, promptPresented: false, settingsOpened: opened)
        }
    }

    private static func prompt(_ id: PermissionID, primitives: PermissionPrimitives) async -> PermissionBackendEvent {
        switch id {
        case .accessibility:
            let granted = primitives.accessibilityTrusted(true)
            return await finish(id, granted: granted, primitives: primitives)
        case .screenRecording:
            let granted = primitives.screenRequest()
            return await finish(id, granted: granted, primitives: primitives)
        case .inputMonitoring:
            let status = primitives.inputStatus()
            if status == .restricted {
                let opened = await openSettings(id, primitives: primitives)
                return PermissionBackendEvent(authorization: .restricted, promptPresented: false, settingsOpened: opened)
            }
            let granted = primitives.inputRequest()
            return await finish(id, granted: granted, primitives: primitives)
        case .camera:
            return await capture(true, id: id, primitives: primitives)
        case .microphone:
            return await capture(false, id: id, primitives: primitives)
        case .speech:
            return await authorizationRequest(id, primitives: primitives) { await primitives.speechRequest() }
        case .photos:
            return await authorizationRequest(id, primitives: primitives) { await primitives.photosRequest(false) }
        case .photosAddOnly:
            return await authorizationRequest(id, primitives: primitives) { await primitives.photosRequest(true) }
        case .contacts:
            return await authorizationRequest(id, primitives: primitives) { await primitives.contactsRequest() }
        case .calendars:
            return await authorizationRequest(id, primitives: primitives) { await primitives.eventsRequest(false) }
        case .reminders:
            return await authorizationRequest(id, primitives: primitives) { await primitives.eventsRequest(true) }
        case .mediaLibrary:
            return await authorizationRequest(id, primitives: primitives) { await primitives.mediaRequest() }
        case .notifications:
            return await authorizationRequest(id, primitives: primitives) { await primitives.notificationRequest() }
        case .location:
            return await authorizationRequest(id, primitives: primitives) { await primitives.locationRequest() }
        case .bluetooth:
            return await authorizationRequest(id, primitives: primitives) { await primitives.bluetoothRequest() }
        case .home:
            let opened = await openSettings(id, primitives: primitives)
            let authorization = primitives.homeStatus()
            return PermissionBackendEvent(
                authorization: authorization,
                promptPresented: false,
                settingsOpened: opened
            )
        default:
            let opened = await openSettings(id, primitives: primitives)
            return PermissionBackendEvent(authorization: .unknown, promptPresented: false, settingsOpened: opened)
        }
    }

    private static func capture(
        _ video: Bool,
        id: PermissionID,
        primitives: PermissionPrimitives
    ) async -> PermissionBackendEvent {
        let current = primitives.captureStatus(video)
        if current == .restricted {
            let opened = await openSettings(id, primitives: primitives)
            return PermissionBackendEvent(authorization: .restricted, promptPresented: false, settingsOpened: opened)
        }
        let granted = await primitives.captureRequest(video)
        return await finish(id, granted: granted, primitives: primitives)
    }

    private static func authorizationRequest(
        _ id: PermissionID,
        primitives: PermissionPrimitives,
        body: () async -> PermissionAuthorization
    ) async -> PermissionBackendEvent {
        let authorization = await body()
        var opened = false
        if authorization == .denied || authorization == .restricted {
            opened = await openSettings(id, primitives: primitives)
        }
        return PermissionBackendEvent(
            authorization: authorization,
            promptPresented: true,
            settingsOpened: opened
        )
    }

    private static func finish(
        _ id: PermissionID,
        granted: Bool,
        primitives: PermissionPrimitives
    ) async -> PermissionBackendEvent {
        if granted {
            return PermissionBackendEvent(authorization: .granted, promptPresented: true, settingsOpened: false)
        }
        let opened = await openSettings(id, primitives: primitives)
        return PermissionBackendEvent(authorization: .denied, promptPresented: true, settingsOpened: opened)
    }
}

struct SystemPermissionBackend: PermissionBackend, Sendable {
    var primitives: PermissionPrimitives

    init() {
        self.init(primitives: .live)
    }

    init(primitives: PermissionPrimitives) {
        self.primitives = primitives
    }

    func probe(_ id: PermissionID) -> PermissionAuthorization {
        PermissionDecider.probe(id, primitives: primitives)
    }

    func request(_ id: PermissionID) async -> PermissionBackendEvent {
        await PermissionDecider.request(id, primitives: primitives)
    }

    func openSettings(for id: PermissionID) async -> Bool {
        await PermissionDecider.openSettings(id, primitives: primitives)
    }

    func reset(_ id: PermissionID, bundleIdentifier: String?) throws {
        try PermissionDecider.reset(id, bundleIdentifier: bundleIdentifier, primitives: primitives)
    }
}
