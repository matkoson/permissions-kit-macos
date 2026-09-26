import XCTest
@testable import MacPermissionKit

final class BackendTests: XCTestCase {
    func testProbeTouchesTheMatchingPrimitive() {
        let log = CallLog()
        let engine = backend(log)
        for id in PermissionID.allCases {
            _ = engine.probe(id)
        }
        let lines = log.snapshot
        XCTAssertTrue(lines.contains("ax:false"))
        XCTAssertTrue(lines.contains("screen-preflight"))
        XCTAssertTrue(lines.contains("input-status"))
        XCTAssertTrue(lines.contains("capture-status:true"))
        XCTAssertTrue(lines.contains("capture-status:false"))
        XCTAssertTrue(lines.contains("fda"))
        XCTAssertFalse(lines.contains("screen-request"))
        XCTAssertFalse(lines.contains { $0.contains("SCShareableContent") })
    }

    func testProbeMapsGrantedFlags() {
        let log = CallLog()
        let engine = backend(log) { primitives in
            primitives.accessibilityTrusted = { _ in true }
            primitives.screenPreflight = { true }
            primitives.inputStatus = { .granted }
            primitives.captureStatus = { _ in .granted }
            primitives.fullDiskReadable = { true }
            primitives.speechStatus = { .restricted }
            primitives.photosStatus = { _ in .denied }
            primitives.contactsStatus = { .notDetermined }
            primitives.eventsStatus = { _ in .granted }
            primitives.mediaStatus = { .unknown }
            primitives.locationStatus = { .restricted }
            primitives.bluetoothStatus = { .denied }
        }
        XCTAssertEqual(engine.probe(.accessibility), .granted)
        XCTAssertEqual(engine.probe(.screenRecording), .granted)
        XCTAssertEqual(engine.probe(.inputMonitoring), .granted)
        XCTAssertEqual(engine.probe(.camera), .granted)
        XCTAssertEqual(engine.probe(.microphone), .granted)
        XCTAssertEqual(engine.probe(.fullDiskAccess), .granted)
        XCTAssertEqual(engine.probe(.speech), .restricted)
        XCTAssertEqual(engine.probe(.photos), .denied)
        XCTAssertEqual(engine.probe(.photosAddOnly), .denied)
        XCTAssertEqual(engine.probe(.contacts), .notDetermined)
        XCTAssertEqual(engine.probe(.calendars), .granted)
        XCTAssertEqual(engine.probe(.reminders), .granted)
        XCTAssertEqual(engine.probe(.mediaLibrary), .unknown)
        XCTAssertEqual(engine.probe(.location), .restricted)
        XCTAssertEqual(engine.probe(.bluetooth), .denied)
        XCTAssertEqual(engine.probe(.notifications), .unknown)
        XCTAssertEqual(engine.probe(.automation), .unknown)
        XCTAssertEqual(engine.probe(.localNetwork), .unknown)
        XCTAssertEqual(engine.probe(.systemAudioCapture), .unknown)
        XCTAssertEqual(engine.probe(.appManagement), .unknown)
        XCTAssertEqual(engine.probe(.usb), .unknown)
    }

    func testRequestDeniedCameraOpensSettingsAndStaysDenied() async {
        let log = CallLog()
        let engine = backend(log) { primitives in
            primitives.captureStatus = { _ in .notDetermined }
            primitives.captureRequest = { _ in false }
        }
        let event = await engine.request(.camera)
        XCTAssertEqual(event.authorization, .denied)
        XCTAssertTrue(event.promptPresented)
        XCTAssertTrue(event.settingsOpened)
        XCTAssertTrue(log.snapshot.contains { $0.hasPrefix("open:") && $0.contains("Privacy_Camera") })
    }

    func testRestrictedCameraDoesNotRequest() async {
        let log = CallLog()
        let engine = backend(log) { primitives in
            primitives.captureStatus = { _ in .restricted }
        }
        let event = await engine.request(.microphone)
        XCTAssertEqual(event.authorization, .restricted)
        XCTAssertFalse(event.promptPresented)
        XCTAssertTrue(event.settingsOpened)
        XCTAssertFalse(log.snapshot.contains("capture-request:false"))
    }

    func testGrantedScreenRecordingDoesNotOpenSettings() async {
        let log = CallLog()
        let engine = backend(log) { primitives in
            primitives.screenRequest = { log.add("screen-request"); return true }
        }
        let event = await engine.request(.screenRecording)
        XCTAssertEqual(event.authorization, .granted)
        XCTAssertFalse(event.settingsOpened)
        XCTAssertTrue(event.promptPresented)
        XCTAssertFalse(log.snapshot.contains { $0.hasPrefix("open:") })
    }

    func testDeniedScreenRecordingOpensSettings() async {
        let log = CallLog()
        let engine = backend(log) { primitives in
            primitives.screenRequest = { false }
        }
        let event = await engine.request(.screenRecording)
        XCTAssertEqual(event.authorization, .denied)
        XCTAssertTrue(event.settingsOpened)
    }

    func testAccessibilityPromptFlag() async {
        let log = CallLog()
        let engine = backend(log) { primitives in
            primitives.accessibilityTrusted = { prompt in
                log.add("ax:\(prompt)")
                return prompt
            }
        }
        _ = engine.probe(.accessibility)
        let event = await engine.request(.accessibility)
        XCTAssertEqual(event.authorization, .granted)
        XCTAssertEqual(log.snapshot.filter { $0.hasPrefix("ax:") }, ["ax:false", "ax:true"])
    }

    func testInputMonitoringRestrictedAndDenied() async {
        let restrictedLog = CallLog()
        let restricted = backend(restrictedLog) { primitives in
            primitives.inputStatus = { .restricted }
        }
        let restrictedEvent = await restricted.request(.inputMonitoring)
        XCTAssertEqual(restrictedEvent.authorization, .restricted)
        XCTAssertFalse(restrictedLog.snapshot.contains("input-request"))

        let deniedLog = CallLog()
        let denied = backend(deniedLog) { primitives in
            primitives.inputStatus = { .denied }
            primitives.inputRequest = { deniedLog.add("input-request"); return false }
        }
        let deniedEvent = await denied.request(.inputMonitoring)
        XCTAssertEqual(deniedEvent.authorization, .denied)
        XCTAssertTrue(deniedEvent.settingsOpened)
        XCTAssertTrue(deniedLog.snapshot.contains("input-request"))
    }

    func testFullDiskRequestNeverReportsGranted() async {
        let log = CallLog()
        let engine = backend(log) { primitives in
            primitives.fullDiskReadable = { true }
            primitives.openURL = { _ in true }
        }
        XCTAssertEqual(engine.probe(.fullDiskAccess), .granted)
        let event = await engine.request(.fullDiskAccess)
        XCTAssertEqual(event.authorization, .unknown)
        XCTAssertTrue(event.settingsOpened)
        XCTAssertFalse(event.promptPresented)
        let app = await engine.request(.appManagement)
        XCTAssertEqual(app.authorization, .unknown)
        XCTAssertTrue(app.settingsOpened)
    }

    func testLocalNetworkStaysUnknown() async {
        let log = CallLog()
        let engine = backend(log)
        let event = await engine.request(.localNetwork)
        XCTAssertEqual(event.authorization, .unknown)
        XCTAssertTrue(event.promptPresented)
        XCTAssertFalse(event.settingsOpened)
        XCTAssertTrue(log.snapshot.contains("lan"))
    }

    func testAutomationDeniedOpensSettings() async {
        let log = CallLog()
        let engine = backend(log) { primitives in
            primitives.automationRequest = { _ in .denied }
        }
        let event = await engine.request(.automation)
        XCTAssertEqual(event.authorization, .denied)
        XCTAssertTrue(event.settingsOpened)
        XCTAssertTrue(event.promptPresented)
    }

    func testAutomationTargetProbesUseStatusPrimitive() {
        let log = CallLog()
        let engine = backend(log) { primitives in
            primitives.automationStatus = { target in
                log.add("automation-status:\(target)")
                return target == "System Events" ? .granted : .denied
            }
        }
        XCTAssertEqual(engine.probe(.automation), .granted)
        XCTAssertEqual(engine.probe(.automationShortcutsEvents), .denied)
        XCTAssertEqual(engine.probe(.automationTestFlight), .denied)
        XCTAssertEqual(engine.probe(.home), .unknown)
        XCTAssertEqual(engine.probe(.developerTools), .unknown)
        XCTAssertTrue(log.snapshot.contains("automation-status:System Events"))
        XCTAssertTrue(log.snapshot.contains("home-status"))
        XCTAssertTrue(log.snapshot.contains("devtools-status"))
    }

    func testHomeRequestOpensSettings() async {
        let log = CallLog()
        let engine = backend(log) { primitives in
            primitives.homeStatus = { .denied }
        }
        let event = await engine.request(.home)
        XCTAssertTrue(event.settingsOpened)
        // settingsOnly path reports unknown from the request event itself
        XCTAssertEqual(event.authorization, .unknown)
        XCTAssertTrue(log.snapshot.contains { $0.hasPrefix("open:") && $0.contains("Privacy_HomeKit") })
    }

    func testAutomationTargetRequestUsesNamedTarget() async {
        let log = CallLog()
        let engine = backend(log) { primitives in
            primitives.automationRequest = { target in
                log.add("automation:\(target)")
                return .granted
            }
        }
        let event = await engine.request(.automationGoogleChrome)
        XCTAssertEqual(event.authorization, .granted)
        XCTAssertTrue(log.snapshot.contains("automation:Google Chrome"))
    }

    func testFrameworkRequestsMapAuthorization() async {
        let cases: [(PermissionID, String)] = [
            (.speech, "speech-request"),
            (.photos, "photos-request:false"),
            (.photosAddOnly, "photos-request:true"),
            (.contacts, "contacts-request"),
            (.calendars, "events-request:false"),
            (.reminders, "events-request:true"),
            (.notifications, "note-request"),
            (.location, "location-request"),
            (.bluetooth, "bluetooth-request"),
        ]
        for (id, marker) in cases {
            let log = CallLog()
            let engine = backend(log)
            let denied = await engine.request(id)
            XCTAssertEqual(denied.authorization, id == .location || id == .bluetooth ? .notDetermined : .denied, id.rawValue)
            XCTAssertTrue(log.snapshot.contains(marker), id.rawValue)
        }

        let grantedLog = CallLog()
        let granted = backend(grantedLog) { primitives in
            primitives.speechRequest = { .granted }
            primitives.photosRequest = { _ in .granted }
            primitives.contactsRequest = { .restricted }
        }
        let speech = await granted.request(.speech)
        XCTAssertEqual(speech.authorization, .granted)
        XCTAssertFalse(speech.settingsOpened)
        let contacts = await granted.request(.contacts)
        XCTAssertEqual(contacts.authorization, .restricted)
        XCTAssertTrue(contacts.settingsOpened)
    }

    func testOpenSettingsFallsBackWhenPrimaryFails() async {
        let log = CallLog()
        let engine = backend(log) { primitives in
            primitives.openURL = { url in
                log.add("open:\(url.absoluteString)")
                return !url.absoluteString.contains("PrivacySecurity.extension")
            }
        }
        let opened = await engine.openSettings(for: .microphone)
        XCTAssertTrue(opened)
        XCTAssertEqual(log.snapshot.filter { $0.hasPrefix("open:") }.count, 2)
    }

    func testOpenSettingsFalseWhenBothFail() async {
        let log = CallLog()
        let engine = backend(log) { primitives in
            primitives.openURL = { url in
                log.add(url.absoluteString)
                return false
            }
        }
        let opened = await engine.openSettings(for: .usb)
        XCTAssertFalse(opened)
    }

    func testResetBuildsArgumentsAndRejectsMissingService() throws {
        let log = CallLog()
        let engine = backend(log)
        try engine.reset(.screenRecording, bundleIdentifier: "app.example.kit")
        let line = log.snapshot.joined(separator: "\n")
        XCTAssertTrue(line.contains("reset"))
        XCTAssertTrue(line.contains("kTCCServiceScreenCapture"))
        XCTAssertTrue(line.contains("app.example.kit"))
        XCTAssertTrue(line.contains("tccutil"))
        XCTAssertThrowsError(try engine.reset(.appManagement, bundleIdentifier: "app.example.kit")) { error in
            XCTAssertEqual(error as? PermissionKitError, .resetUnsupported(.appManagement))
        }
        let failing = backend(CallLog()) { primitives in
            primitives.run = { _ in 9 }
        }
        XCTAssertThrowsError(try failing.reset(.camera, bundleIdentifier: nil)) { error in
            XCTAssertEqual(error as? PermissionKitError, .resetFailed(.camera, 9))
        }
        let empty = backend(CallLog())
        try empty.reset(.microphone, bundleIdentifier: "")
        let emptyLog = CallLog()
        let noBundle = backend(emptyLog)
        try noBundle.reset(.microphone, bundleIdentifier: nil)
        XCTAssertFalse(emptyLog.snapshot.joined(separator: " ").contains("nil"))
    }

    func testProcessSpawnerTrueAndFalse() throws {
        XCTAssertEqual(try ProcessSpawner.run(["/usr/bin/true"]), 0)
        XCTAssertEqual(try ProcessSpawner.run(["/usr/bin/false"]), 1)
        XCTAssertThrowsError(try ProcessSpawner.run([])) { error in
            XCTAssertEqual(error as? PermissionKitError, .backend("empty command"))
        }
        XCTAssertThrowsError(try ProcessSpawner.run([""])) 
    }

    func testCameraGrantPath() async {
        let log = CallLog()
        let engine = backend(log) { primitives in
            primitives.captureStatus = { _ in .notDetermined }
            primitives.captureRequest = { video in video }
        }
        let event = await engine.request(.camera)
        XCTAssertEqual(event.authorization, .granted)
        XCTAssertFalse(event.settingsOpened)
    }
}
