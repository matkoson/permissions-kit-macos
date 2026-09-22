import XCTest
@testable import MacPermissionKit

@MainActor
final class SessionControllerTests: XCTestCase {
    func testSessionImplementsStartupSlot() async {
        let (orchestrator, _) = session(
            required: [.accessibility, .screenRecording],
            probes: [
                .accessibility: .granted,
                .screenRecording: .notDetermined,
            ]
        )
        let controller = PermissionSessionController(orchestrator: orchestrator)
        controller.presentStartup()
        XCTAssertTrue(controller.isStartupPresented)
        XCTAssertEqual(controller.focusedID, .screenRecording)
        XCTAssertFalse(controller.canDismiss)

        controller.refreshFromWindowKey()
        await controller.advance()
        XCTAssertNil(controller.orchestrator.pending)
    }

    func testSkipOptionalClearsDenied() async {
        let (orchestrator, _) = session(
            required: [.microphone, .camera],
            policy: PermissionPresentationPolicy(
                startupIDs: [.microphone, .camera],
                optionalIDs: [.camera],
                blockUntilRequiredGranted: true
            ),
            probes: [
                .microphone: .granted,
                .camera: .denied,
            ]
        )
        let controller = PermissionSessionController(orchestrator: orchestrator)
        controller.presentStartup()
        await controller.request(.camera)
        XCTAssertEqual(controller.deniedRecord?.id, .camera)
        controller.skipCurrent()
        XCTAssertNil(controller.deniedRecord)
        XCTAssertTrue(controller.orchestrator.skipped.contains(.camera))
    }

    func testRowControllerForwards() async {
        let (orchestrator, _) = session(
            required: [.microphone],
            probes: [.microphone: .notDetermined]
        )
        let controller = PermissionSessionController(orchestrator: orchestrator)
        let row = PermissionRowController(permissionID: .microphone, session: controller)
        XCTAssertEqual(row.permissionID, .microphone)
        await row.request()
        await row.openSettings()
        XCTAssertEqual(controller.orchestrator.lastResult?.record.id, .microphone)
    }

    func testFinishOnboardingDismisses() {
        let (orchestrator, _) = session(required: [], probes: [:])
        let controller = PermissionSessionController(orchestrator: orchestrator)
        controller.presentStartup()
        controller.finishOnboarding()
        XCTAssertTrue(controller.didFinishOnboarding)
        XCTAssertTrue(controller.canDismiss)
        XCTAssertFalse(controller.isStartupPresented)
    }
}
