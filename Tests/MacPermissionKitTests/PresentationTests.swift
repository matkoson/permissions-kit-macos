import XCTest
@testable import MacPermissionKit

final class PresentationTests: XCTestCase {
    func testStandardPolicy() {
        let policy = PermissionPresentationPolicy.standard
        XCTAssertEqual(policy.startupIDs, PermissionKind.prerequisitesDefaultRequired)
        XCTAssertTrue(policy.optionalIDs.isEmpty)
        XCTAssertTrue(policy.blockUntilRequiredGranted)
        XCTAssertTrue(policy.blockingIDs.contains(.fullDiskAccess))
        XCTAssertTrue(policy.blockingIDs.contains(.accessibility))
        XCTAssertFalse(policy.blockingIDs.contains(.appManagement))
    }

    func testLegacyStartupPolicy() {
        let policy = PermissionPresentationPolicy.legacyStartup
        XCTAssertEqual(policy.startupIDs, PermissionKind.startupDefaultOrder)
        XCTAssertEqual(
            policy.optionalIDs,
            [.camera, .systemAudioCapture, .automation, .localNetwork]
        )
        XCTAssertFalse(policy.blockingIDs.contains(.camera))
        XCTAssertTrue(policy.blockingIDs.contains(.microphone))
    }

    func testCustomPolicy() {
        let policy = PermissionPresentationPolicy(
            startupIDs: [.camera],
            optionalIDs: [],
            blockUntilRequiredGranted: false
        )
        XCTAssertEqual(policy.blockingIDs, [.camera])
        XCTAssertFalse(policy.blockUntilRequiredGranted)
    }

    func testSlotCopy() {
        XCTAssertEqual(PermissionSlotCopy.primaryButtonTitle(id: .camera), "Request")
        XCTAssertEqual(PermissionSlotCopy.primaryButtonTitle(id: .automation), "Trigger Prompt")
        XCTAssertEqual(PermissionSlotCopy.primaryButtonTitle(id: .localNetwork), "Trigger Prompt")
        XCTAssertEqual(PermissionSlotCopy.primaryButtonTitle(id: .fullDiskAccess), "Open Settings")
        XCTAssertEqual(PermissionSlotCopy.primaryButtonTitle(id: .usb), "Open Settings")
        XCTAssertTrue(PermissionSlotCopy.showsDragHint(id: .accessibility))
        XCTAssertFalse(PermissionSlotCopy.showsDragHint(id: .camera))
        XCTAssertEqual(
            PermissionSlotCopy.dragIntoListHint(bundleName: "Example", id: .accessibility),
            "Drag Example into the Device Control and Data Access list, then return here."
        )
        XCTAssertEqual(
            PermissionSlotCopy.waitingForPrompt(id: .microphone),
            "Waiting for the Microphone permission dialog."
        )
        XCTAssertEqual(PermissionSlot.allCases.count, 11)
        XCTAssertEqual(PermissionSlot.startupGlassShell.rawValue, "SLOT_StartupGlassShell")
        XCTAssertEqual(PermissionSlot.prerequisitesChecklist.rawValue, "SLOT_PrerequisitesChecklist")
        XCTAssertEqual(PermissionSlot.prerequisitesSplash.rawValue, "SLOT_PrerequisitesSplash")
    }

    func testSourcesDoNotReferenceTheSharePicker() throws {
        let sources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
        let enumerator = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil)
        var sawSwift = false
        while let item = enumerator?.nextObject() as? URL {
            guard item.pathExtension == "swift" else { continue }
            sawSwift = true
            let text = try String(contentsOf: item, encoding: .utf8)
            XCTAssertFalse(text.contains("SCShareableContent"), item.lastPathComponent)
            XCTAssertFalse(text.contains("SCContentSharingPicker"), item.lastPathComponent)
        }
        XCTAssertTrue(sawSwift)
    }
}

@MainActor
private final class ShellDouble: PermissionStartupGlassShellSlot {
    var finished = false
    var advanced = false
    var refreshed = false
    var canDismiss: Bool { finished }
    func refreshFromWindowKey() { refreshed = true }
    func advance() async { advanced = true }
    func finishOnboarding() { finished = true }
}

@MainActor
private final class RowDouble: PermissionRowSlot {
    let permissionID: PermissionID = .camera
    var requested = false
    var opened = false
    func request() async { requested = true }
    func openSettings() async { opened = true }
}

final class SlotConformanceTests: XCTestCase {
    func testHostCanImplementSlots() async {
        let shell = await MainActor.run { ShellDouble() }
        await shell.refreshFromWindowKey()
        await shell.advance()
        await shell.finishOnboarding()
        let canDismiss = await shell.canDismiss
        let advanced = await shell.advanced
        XCTAssertTrue(canDismiss)
        XCTAssertTrue(advanced)
        let row = await MainActor.run { RowDouble() }
        await row.request()
        await row.openSettings()
        let requested = await row.requested
        XCTAssertTrue(requested)
        let permissionID = await row.permissionID
        XCTAssertEqual(permissionID, .camera)
    }
}
