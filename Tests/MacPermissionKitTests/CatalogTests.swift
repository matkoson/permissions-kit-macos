import XCTest
@testable import MacPermissionKit

final class CatalogTests: XCTestCase {
    func testEveryIdentifierHasOneKind() {
        XCTAssertEqual(Set(PermissionKind.all.map(\.id)), Set(PermissionID.allCases))
        XCTAssertEqual(PermissionKind.all.count, PermissionID.allCases.count)
        for id in PermissionID.allCases {
            XCTAssertEqual(PermissionKind.kind(for: id).id, id)
        }
    }

    func testStartupOrder() {
        XCTAssertEqual(
            PermissionKind.startupDefaultOrder,
            [
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
        )
    }

    func testDragIntoListSet() {
        let drag = Set(PermissionKind.all.filter(\.dragIntoListRequired).map(\.id))
        XCTAssertEqual(
            drag,
            [
                .accessibility,
                .screenRecording,
                .systemAudioCapture,
                .inputMonitoring,
                .fullDiskAccess,
                .developerTools,
                .appManagement,
            ]
        )
    }

    func testSettingsOnlyNeverClaimsASystemPrompt() {
        let settingsOnly: Set<PermissionID> = [
            .systemAudioCapture, .fullDiskAccess, .usb, .desktopFolder, .documentsFolder,
            .downloadsFolder, .removableVolumes, .networkVolumes, .developerTools, .appManagement,
        ]
        for id in settingsOnly {
            XCTAssertEqual(PermissionKind.kind(for: id).promptKind, .settingsOnly, id.rawValue)
        }
        XCTAssertEqual(PermissionKind.kind(for: .localNetwork).promptKind, .sideEffectNudge)
        XCTAssertEqual(PermissionKind.kind(for: .automation).promptKind, .sideEffectNudge)
        XCTAssertEqual(PermissionKind.kind(for: .screenRecording).promptKind, .systemPrompt)
    }

    func testUncertainServicesAreNotGuessed() {
        for id in [PermissionID.systemAudioCapture, .localNetwork, .notifications, .usb, .appManagement] {
            XCTAssertNil(PermissionKind.kind(for: id).tccService, id.rawValue)
        }
        XCTAssertEqual(PermissionKind.kind(for: .screenRecording).tccService, "kTCCServiceScreenCapture")
        XCTAssertEqual(PermissionKind.kind(for: .accessibility).tccService, "kTCCServiceAccessibility")
    }

    func testUsageKeysForStartupPrompts() {
        XCTAssertEqual(PermissionKind.kind(for: .camera).usageDescriptionKeys, ["NSCameraUsageDescription"])
        XCTAssertEqual(PermissionKind.kind(for: .microphone).usageDescriptionKeys, ["NSMicrophoneUsageDescription"])
        XCTAssertEqual(PermissionKind.kind(for: .screenRecording).usageDescriptionKeys, ["NSScreenCaptureUsageDescription"])
        XCTAssertEqual(PermissionKind.kind(for: .systemAudioCapture).usageDescriptionKeys, ["NSAudioCaptureUsageDescription"])
        XCTAssertEqual(PermissionKind.kind(for: .automation).usageDescriptionKeys, ["NSAppleEventsUsageDescription"])
        XCTAssertEqual(PermissionKind.kind(for: .localNetwork).usageDescriptionKeys, ["NSLocalNetworkUsageDescription"])
        XCTAssertEqual(PermissionKind.kind(for: .bluetooth).usageDescriptionKeys, ["NSBluetoothAlwaysUsageDescription"])
        XCTAssertTrue(PermissionKind.kind(for: .accessibility).usageDescriptionKeys.isEmpty)
        XCTAssertTrue(PermissionKind.kind(for: .inputMonitoring).usageDescriptionKeys.isEmpty)
        XCTAssertTrue(PermissionKind.kind(for: .fullDiskAccess).usageDescriptionKeys.isEmpty)
    }

    func testSettingsURLsUseModernAndClassicAnchors() {
        let screen = PermissionKind.kind(for: .screenRecording)
        XCTAssertEqual(
            screen.primarySettingsURL?.absoluteString,
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture"
        )
        XCTAssertEqual(
            screen.fallbackSettingsURL?.absoluteString,
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        )
        let usb = PermissionKind.kind(for: .usb)
        XCTAssertEqual(
            usb.primarySettingsURL?.absoluteString,
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension"
        )
        XCTAssertEqual(
            usb.fallbackSettingsURL?.absoluteString,
            "x-apple.systempreferences:com.apple.preference.security"
        )
    }

    func testRelaunchMetadata() {
        XCTAssertEqual(PermissionKind.kind(for: .screenRecording).relaunch, .requiredAfterGrant)
        XCTAssertEqual(PermissionKind.kind(for: .inputMonitoring).relaunch, .requiredAfterGrant)
        XCTAssertEqual(PermissionKind.kind(for: .fullDiskAccess).relaunch, .requiredAfterGrant)
        XCTAssertEqual(PermissionKind.kind(for: .accessibility).relaunch, .recommendedAfterGrant)
        XCTAssertEqual(PermissionKind.kind(for: .appManagement).relaunch, .recommendedAfterGrant)
        XCTAssertEqual(PermissionKind.kind(for: .systemAudioCapture).relaunch, .recommendedAfterGrant)
        XCTAssertEqual(PermissionKind.kind(for: .microphone).relaunch, .none)
    }

    func testIdentifierRawValueRoundTrip() {
        for id in PermissionID.allCases {
            XCTAssertEqual(PermissionID(rawValue: id.rawValue), id)
            XCTAssertEqual(id.id, id.rawValue)
        }
    }
}
