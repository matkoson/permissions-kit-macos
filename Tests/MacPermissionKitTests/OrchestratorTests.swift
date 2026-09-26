import XCTest
@testable import MacPermissionKit

@MainActor
final class OrchestratorTests: XCTestCase {
    func testAdvanceStopsAtFirstUngranted() async {
        let (orchestrator, log) = session(
            required: PermissionKind.startupDefaultOrder,
            policy: .legacyStartup,
            probes: [.accessibility: .granted]
        )
        XCTAssertEqual(orchestrator.nextRequired, .screenRecording)
        let result = await orchestrator.advanceStartup()
        XCTAssertEqual(result?.record.id, .screenRecording)
        XCTAssertNotEqual(result?.record.authorization, .granted)
        XCTAssertFalse(log.snapshot.contains("capture-request:false"))
        XCTAssertFalse(log.snapshot.contains("capture-request:true"))
    }

    func testAdvanceMovesForwardAfterGrant() async {
        let log = CallLog()
        let engine = backend(log) { primitives in
            primitives.accessibilityTrusted = { prompt in
                log.add("ax:\(prompt)")
                return prompt
            }
            primitives.screenPreflight = { false }
            primitives.screenRequest = { true }
        }
        let orchestrator = PermissionOrchestrator(
            required: [.accessibility, .screenRecording],
            policy: .standard,
            backend: engine,
            bundleIdentifier: "app.example.kit"
        )
        let first = await orchestrator.advanceStartup()
        XCTAssertEqual(first?.record.id, .accessibility)
        XCTAssertEqual(first?.record.authorization, .granted)
        XCTAssertTrue(orchestrator.relaunchRequired)
        let second = await orchestrator.advanceStartup()
        XCTAssertEqual(second?.record.id, .screenRecording)
    }

    func testScreenRecordingGrantSetsRelaunch() async {
        let log = CallLog()
        let engine = backend(log) { primitives in
            primitives.screenRequest = { true }
        }
        let orchestrator = PermissionOrchestrator(
            required: [.screenRecording],
            policy: .standard,
            backend: engine,
            bundleIdentifier: nil
        )
        let result = await orchestrator.request(.screenRecording)
        XCTAssertEqual(result.record.authorization, .granted)
        XCTAssertTrue(result.relaunchRequired)
        XCTAssertTrue(orchestrator.relaunchRequired)
        XCTAssertNil(orchestrator.pending)
    }

    func testInputMonitoringGrantSetsRelaunch() async {
        let log = CallLog()
        let engine = backend(log) { primitives in
            primitives.inputStatus = { .denied }
            primitives.inputRequest = { true }
        }
        let orchestrator = PermissionOrchestrator(
            required: [.inputMonitoring],
            policy: .standard,
            backend: engine,
            bundleIdentifier: nil
        )
        let result = await orchestrator.request(.inputMonitoring)
        XCTAssertTrue(result.relaunchRequired)
    }

    func testDeniedCameraStaysDenied() async {
        let log = CallLog()
        let engine = backend(log) { primitives in
            primitives.captureStatus = { _ in .notDetermined }
            primitives.captureRequest = { _ in false }
        }
        let orchestrator = PermissionOrchestrator(
            required: [.camera],
            policy: .standard,
            backend: engine,
            bundleIdentifier: nil
        )
        let result = await orchestrator.request(.camera)
        XCTAssertEqual(result.record.authorization, .denied)
        XCTAssertTrue(result.settingsOpened)
        XCTAssertEqual(orchestrator.snapshot.authorization(for: .camera), .denied)
        XCTAssertFalse(result.relaunchRequired)
    }

    func testFullDiskRequestDoesNotFlipSnapshotToGrantedFromTheRequestItself() async {
        let log = CallLog()
        let engine = backend(log) { primitives in
            primitives.fullDiskReadable = { false }
        }
        let orchestrator = PermissionOrchestrator(
            required: [.fullDiskAccess],
            policy: .standard,
            backend: engine,
            bundleIdentifier: nil
        )
        let result = await orchestrator.request(.fullDiskAccess)
        XCTAssertEqual(result.record.authorization, .unknown)
        XCTAssertNotEqual(orchestrator.snapshot.authorization(for: .fullDiskAccess), .granted)
    }

    func testRefreshObservesFullDiskTransition() {
        let log = CallLog()
        let readable = FlagBox(false)
        let engine = backend(log) { primitives in
            primitives.fullDiskReadable = { readable.value }
        }
        let orchestrator = PermissionOrchestrator(
            required: [.fullDiskAccess],
            policy: .standard,
            backend: engine,
            bundleIdentifier: nil
        )
        XCTAssertEqual(orchestrator.snapshot.authorization(for: .fullDiskAccess), .denied)
        XCTAssertFalse(orchestrator.relaunchRequired)
        readable.value = true
        orchestrator.refresh()
        XCTAssertEqual(orchestrator.snapshot.authorization(for: .fullDiskAccess), .granted)
        XCTAssertTrue(orchestrator.relaunchRequired)
    }

    func testSkipOptionalAndRejectRequired() throws {
        let (orchestrator, _) = session(
            required: PermissionKind.startupDefaultOrder,
            policy: .legacyStartup
        )
        XCTAssertThrowsError(try orchestrator.skip(.microphone)) { error in
            XCTAssertEqual(error as? PermissionKitError, .skipNotAllowed(.microphone))
        }
        try orchestrator.skip(.camera)
        XCTAssertTrue(orchestrator.skipped.contains(.camera))
        if orchestrator.snapshot.authorization(for: .accessibility) != .granted {
            XCTAssertNotEqual(orchestrator.nextRequired, .camera)
        }
    }

    func testAllRequiredIgnoresOptional() async {
        let log = CallLog()
        let engine = backend(log) { primitives in
            primitives.accessibilityTrusted = { _ in true }
            primitives.screenPreflight = { true }
            primitives.inputStatus = { .granted }
            primitives.captureStatus = { video in video ? .notDetermined : .granted }
            primitives.fullDiskReadable = { true }
        }
        let orchestrator = PermissionOrchestrator(
            required: PermissionKind.startupDefaultOrder,
            policy: .legacyStartup,
            backend: engine,
            bundleIdentifier: nil
        )
        XCTAssertTrue(orchestrator.allRequiredSatisfied)
        XCTAssertEqual(orchestrator.nextRequired, .camera)
        
        let advanced = await orchestrator.advanceStartup()
        XCTAssertEqual(advanced?.record.id, .camera)
    }

    func testSatisfiedAdvanceReturnsNil() async {
        let log = CallLog()
        let engine = backend(log) { primitives in
            primitives.accessibilityTrusted = { _ in true }
        }
        let orchestrator = PermissionOrchestrator(
            required: [.accessibility],
            policy: .standard,
            backend: engine,
            bundleIdentifier: nil
        )
        XCTAssertTrue(orchestrator.allRequiredSatisfied)
        XCTAssertNil(orchestrator.nextRequired)
        let result = await orchestrator.advanceStartup()
        XCTAssertNil(result)
    }

    func testPendingClearedAfterRequest() async {
        let log = CallLog()
        let engine = backend(log) { primitives in
            primitives.captureRequest = { video in
                log.add("during:\(video)")
                return true
            }
            primitives.captureStatus = { _ in .notDetermined }
        }
        let orchestrator = PermissionOrchestrator(
            required: [.microphone],
            policy: .standard,
            backend: engine,
            bundleIdentifier: "app.example.kit"
        )
        XCTAssertNil(orchestrator.pending)
        _ = await orchestrator.request(.microphone)
        XCTAssertNil(orchestrator.pending)
        XCTAssertEqual(orchestrator.lastResult?.record.id, .microphone)
    }

    func testOpenSettingsAndReset() async throws {
        let log = CallLog()
        let engine = backend(log)
        let orchestrator = PermissionOrchestrator(
            required: [.screenRecording],
            policy: .standard,
            backend: engine,
            bundleIdentifier: "app.example.kit"
        )
        let opened = await orchestrator.openSettings(.screenRecording)
        XCTAssertTrue(opened.settingsOpened)
        XCTAssertFalse(opened.promptPresented)
        try orchestrator.reset(.screenRecording)
        XCTAssertTrue(log.snapshot.contains { $0.contains("kTCCServiceScreenCapture") && $0.contains("app.example.kit") })
        XCTAssertThrowsError(try orchestrator.reset(.notifications))
    }

    func testDuplicateRequiredIsCollapsed() {
        let (orchestrator, _) = session(required: [.camera, .camera, .microphone])
        XCTAssertEqual(orchestrator.required, [.camera, .microphone])
    }

    func testEmptyRequiredIsSatisfied() {
        let (orchestrator, _) = session(required: [])
        XCTAssertTrue(orchestrator.allRequiredSatisfied)
        XCTAssertNil(orchestrator.nextRequired)
        XCTAssertEqual(orchestrator.snapshot.records.count, PermissionID.allCases.count)
        XCTAssertGreaterThanOrEqual(orchestrator.snapshot.grantedCount, 0)
        XCTAssertEqual(orchestrator.requiredGrantedCount, 0)
    }

    func testLocalNetworkRequestStaysUnknownOnTheSession() async {
        let log = CallLog()
        let engine = backend(log)
        let orchestrator = PermissionOrchestrator(
            required: [.localNetwork],
            policy: .standard,
            backend: engine,
            bundleIdentifier: nil
        )
        let result = await orchestrator.request(.localNetwork)
        XCTAssertEqual(result.record.authorization, .unknown)
        XCTAssertEqual(orchestrator.snapshot.authorization(for: .localNetwork), .unknown)
    }

    func testResetRequiresBundleIdentifier() {
        let engine = backend(CallLog())
        let orchestrator = PermissionOrchestrator(
            required: [.microphone],
            policy: .standard,
            backend: engine,
            bundleIdentifier: nil
        )
        XCTAssertThrowsError(try orchestrator.reset(.microphone)) { error in
            XCTAssertEqual(error as? PermissionKitError, .bundleIdentifierRequired)
        }
        let blank = PermissionOrchestrator(
            required: [.microphone],
            policy: .standard,
            backend: engine,
            bundleIdentifier: ""
        )
        XCTAssertThrowsError(try blank.reset(.microphone)) { error in
            XCTAssertEqual(error as? PermissionKitError, .bundleIdentifierRequired)
        }
    }

    func testRefreshKeepsGrantedWhenProbeIsUnknown() async {
        let log = CallLog()
        let engine = backend(log) { primitives in
            primitives.notificationRequest = { .granted }
        }
        let orchestrator = PermissionOrchestrator(
            required: [.notifications],
            policy: .standard,
            backend: engine,
            bundleIdentifier: nil
        )
        let result = await orchestrator.request(.notifications)
        XCTAssertEqual(result.record.authorization, .granted)
        orchestrator.refresh()
        XCTAssertEqual(orchestrator.snapshot.authorization(for: .notifications), .granted)
    }

    func testSnapshotHelpers() {
        let snapshot = PermissionSnapshot(records: [
            PermissionRecord(id: .camera, authorization: .granted),
            PermissionRecord(id: .microphone, authorization: .denied),
        ])
        XCTAssertEqual(snapshot.grantedCount, 1)
        XCTAssertEqual(snapshot.grantedCount(among: [.camera, .microphone]), 1)
        XCTAssertEqual(snapshot.authorization(for: .usb), .unsupported)
        XCTAssertEqual(snapshot.record(for: .usb).authorization, .unsupported)
    }
}

final class FlagBox: @unchecked Sendable {
    var value: Bool
    init(_ value: Bool) { self.value = value }
}
