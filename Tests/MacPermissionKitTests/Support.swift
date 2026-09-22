import XCTest
@testable import MacPermissionKit

final class CallLog: @unchecked Sendable {
    private let lock = NSLock()
    private var lines: [String] = []
    func add(_ line: String) {
        lock.lock()
        lines.append(line)
        lock.unlock()
    }
    var snapshot: [String] {
        lock.lock()
        defer { lock.unlock() }
        return lines
    }
}

func recordingPrimitives(_ log: CallLog) -> PermissionPrimitives {
    PermissionPrimitives(
        accessibilityTrusted: { prompt in log.add("ax:\(prompt)"); return false },
        screenPreflight: { log.add("screen-preflight"); return false },
        screenRequest: { log.add("screen-request"); return false },
        inputStatus: { log.add("input-status"); return .denied },
        inputRequest: { log.add("input-request"); return false },
        captureStatus: { video in log.add("capture-status:\(video)"); return .notDetermined },
        captureRequest: { video in log.add("capture-request:\(video)"); return false },
        speechStatus: { log.add("speech-status"); return .notDetermined },
        speechRequest: { log.add("speech-request"); return .denied },
        photosStatus: { addOnly in log.add("photos-status:\(addOnly)"); return .notDetermined },
        photosRequest: { addOnly in log.add("photos-request:\(addOnly)"); return .denied },
        contactsStatus: { log.add("contacts-status"); return .notDetermined },
        contactsRequest: { log.add("contacts-request"); return .denied },
        eventsStatus: { reminders in log.add("events-status:\(reminders)"); return .notDetermined },
        eventsRequest: { reminders in log.add("events-request:\(reminders)"); return .denied },
        mediaStatus: { log.add("media-status"); return .notDetermined },
        mediaRequest: { log.add("media-request"); return .denied },
        notificationStatus: { log.add("note-status"); return .notDetermined },
        notificationRequest: { log.add("note-request"); return .denied },
        locationStatus: { log.add("location-status"); return .notDetermined },
        locationRequest: { log.add("location-request"); return .notDetermined },
        bluetoothStatus: { log.add("bluetooth-status"); return .notDetermined },
        bluetoothRequest: { log.add("bluetooth-request"); return .notDetermined },
        automationRequest: { log.add("automation"); return .denied },
        localNetworkNudge: { log.add("lan") },
        fullDiskReadable: { log.add("fda"); return false },
        openURL: { url in log.add("open:\(url.absoluteString)"); return true },
        run: { args in log.add(args.joined(separator: " ")); return 0 }
    )
}

func backend(_ log: CallLog, _ edit: (inout PermissionPrimitives) -> Void = { _ in }) -> SystemPermissionBackend {
    var primitives = recordingPrimitives(log)
    edit(&primitives)
    return SystemPermissionBackend(primitives: primitives)
}

@MainActor
func session(
    required: [PermissionID] = PermissionKind.startupDefaultOrder,
    policy: PermissionPresentationPolicy = .standard,
    probes: [PermissionID: PermissionAuthorization] = [:],
    log: CallLog = CallLog(),
    bundleIdentifier: String? = "app.example.kit"
) -> (PermissionOrchestrator, CallLog) {
    let engine = backend(log) { primitives in
        let baseProbe = primitives
        primitives.accessibilityTrusted = { prompt in
            log.add("ax:\(prompt)")
            return probes[.accessibility] == .granted
        }
        primitives.screenPreflight = {
            log.add("screen-preflight")
            return probes[.screenRecording] == .granted
        }
        primitives.inputStatus = {
            log.add("input-status")
            return probes[.inputMonitoring] ?? .denied
        }
        primitives.captureStatus = { video in
            log.add("capture-status:\(video)")
            return video ? (probes[.camera] ?? .notDetermined) : (probes[.microphone] ?? .notDetermined)
        }
        primitives.speechStatus = { probes[.speech] ?? .notDetermined }
        primitives.photosStatus = { addOnly in addOnly ? (probes[.photosAddOnly] ?? .notDetermined) : (probes[.photos] ?? .notDetermined) }
        primitives.contactsStatus = { probes[.contacts] ?? .notDetermined }
        primitives.eventsStatus = { reminders in reminders ? (probes[.reminders] ?? .notDetermined) : (probes[.calendars] ?? .notDetermined) }
        primitives.mediaStatus = { probes[.mediaLibrary] ?? .notDetermined }
        primitives.locationStatus = { probes[.location] ?? .notDetermined }
        primitives.bluetoothStatus = { probes[.bluetooth] ?? .notDetermined }
        primitives.fullDiskReadable = { probes[.fullDiskAccess] == .granted }
        _ = baseProbe
    }
    let orchestrator = PermissionOrchestrator(
        required: required,
        policy: policy,
        backend: engine,
        bundleIdentifier: bundleIdentifier
    )
    return (orchestrator, log)
}
