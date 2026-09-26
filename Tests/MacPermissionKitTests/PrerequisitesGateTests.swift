import XCTest
@testable import MacPermissionKit

@MainActor
final class PrerequisitesGateTests: XCTestCase {
    func testDefaultRequiredMatrix() {
        XCTAssertEqual(
            PermissionKind.prerequisitesDefaultRequired,
            [
                .fullDiskAccess,
                .accessibility,
                .developerTools,
                .calendars,
                .home,
                .mediaLibrary,
                .reminders,
                .automation,
                .automationShortcutsEvents,
                .automationTestFlight,
                .automationGoogleChrome,
                .automationTextEdit,
            ]
        )
        XCTAssertFalse(PermissionKind.prerequisitesDefaultRequired.contains(.appManagement))
        let withApp = PrerequisitesConfiguration.withAppManagement
        XCTAssertTrue(withApp.required.contains(.appManagement))
        XCTAssertTrue(withApp.includesAppManagement)
    }

    func testAggregateChecklistUncheckedUntilAllGranted() {
        let (orchestrator, _) = session(
            required: [.fullDiskAccess, .accessibility],
            probes: [.fullDiskAccess: .granted, .accessibility: .denied]
        )
        let gate = PrerequisitesNavigationGate(
            configuration: PrerequisitesConfiguration(required: [.fullDiskAccess, .accessibility]),
            orchestrator: orchestrator
        )
        gate.refresh()
        XCTAssertFalse(gate.isChecklistSatisfied)
        XCTAssertEqual(gate.landingDestination(), .prerequisites)
        XCTAssertEqual(gate.navigate(to: .home), .prerequisites)
        XCTAssertFalse(gate.isEnabled(.home))
        XCTAssertTrue(gate.isEnabled(.prerequisites))
    }

    func testAggregateChecklistCheckedWhenAllGranted() {
        let (orchestrator, _) = session(
            required: [.fullDiskAccess, .accessibility],
            probes: [.fullDiskAccess: .granted, .accessibility: .granted]
        )
        let gate = PrerequisitesNavigationGate(
            configuration: PrerequisitesConfiguration(required: [.fullDiskAccess, .accessibility]),
            orchestrator: orchestrator
        )
        gate.refresh()
        XCTAssertTrue(gate.isChecklistSatisfied)
        XCTAssertEqual(gate.landingDestination(), .home)
        XCTAssertEqual(gate.navigate(to: .home), .home)
        XCTAssertTrue(gate.isEnabled(.home))
    }

    func testSidebarDividerAndDisabledHomeWhileIncomplete() {
        let (orchestrator, _) = session(
            required: [.fullDiskAccess],
            probes: [.fullDiskAccess: .denied]
        )
        let gate = PrerequisitesNavigationGate(
            configuration: PrerequisitesConfiguration(required: [.fullDiskAccess]),
            orchestrator: orchestrator
        )
        gate.refresh()
        let items = gate.sidebarItems
        XCTAssertEqual(items.map(\.kind), [.destination, .divider, .destination])
        XCTAssertEqual(items[0].destination, .prerequisites)
        XCTAssertEqual(items[0].title, "Prerequisites")
        XCTAssertTrue(items[0].isEnabled)
        XCTAssertEqual(items[2].destination, .home)
        XCTAssertFalse(items[2].isEnabled)
    }

    func testRefreshForcesBackToPrerequisitesWhenRequiredFails() {
        let log = CallLog()
        let flag = MutableFlag(true)
        let engine = backend(log) { primitives in
            primitives.fullDiskReadable = {
                flag.value
            }
        }
        let orchestrator = PermissionOrchestrator(
            required: [.fullDiskAccess],
            policy: PermissionPresentationPolicy(startupIDs: [.fullDiskAccess], optionalIDs: []),
            backend: engine,
            bundleIdentifier: "app.example.kit"
        )
        let gate = PrerequisitesNavigationGate(
            configuration: PrerequisitesConfiguration(required: [.fullDiskAccess]),
            orchestrator: orchestrator
        )
        gate.refresh()
        XCTAssertTrue(gate.isChecklistSatisfied)
        _ = gate.navigate(to: .home)
        XCTAssertEqual(gate.selectedDestination, .home)
        flag.value = false
        gate.refresh()
        XCTAssertFalse(gate.isChecklistSatisfied)
        XCTAssertEqual(gate.selectedDestination, .prerequisites)
    }

    func testBootstrapLanding() {
        let (orchestrator, _) = session(
            required: [.fullDiskAccess],
            probes: [.fullDiskAccess: .granted]
        )
        let gate = PrerequisitesNavigationGate(
            configuration: PrerequisitesConfiguration(required: [.fullDiskAccess]),
            orchestrator: orchestrator
        )
        XCTAssertTrue(gate.isBootstrapping)
        gate.bootstrapIfNeeded()
        XCTAssertFalse(gate.isBootstrapping)
        XCTAssertTrue(gate.didBootstrap)
        XCTAssertEqual(gate.selectedDestination, .home)
    }

    func testAccessibilityCopyUsesDeviceControlName() {
        XCTAssertEqual(
            PermissionKind.kind(for: .accessibility).systemSettingsTitle,
            "Device Control and Data Access"
        )
        XCTAssertEqual(
            PermissionKind.kind(for: .mediaLibrary).systemSettingsTitle,
            "Media & Apple Music"
        )
        XCTAssertEqual(PermissionKind.kind(for: .home).id, .home)
        XCTAssertEqual(PermissionID.automation.automationTargetName, "System Events")
        XCTAssertEqual(PermissionID.automationTestFlight.automationTargetName, "TestFlight")
    }

    func testNavigateKeepsHomeWhenSatisfiedAndRefreshMidSession() {
        let (orchestrator, _) = session(
            required: [.fullDiskAccess],
            probes: [.fullDiskAccess: .granted]
        )
        let gate = PrerequisitesNavigationGate(
            configuration: PrerequisitesConfiguration(required: [.fullDiskAccess]),
            orchestrator: orchestrator
        )
        gate.bootstrapIfNeeded()
        XCTAssertEqual(gate.selectedDestination, .home)
        XCTAssertEqual(gate.checklistItems.count, 1)
        _ = gate.navigate(to: .prerequisites)
        XCTAssertEqual(gate.selectedDestination, .prerequisites)
        gate.refresh()
        // After bootstrap, refresh while satisfied does not auto-jump away from Prerequisites.
        XCTAssertEqual(gate.selectedDestination, .prerequisites)
        gate.bootstrapIfNeeded()
        XCTAssertTrue(gate.didBootstrap)
    }

    func testResolveRedirectsWhenIncomplete() {
        let (orchestrator, _) = session(
            required: [.fullDiskAccess],
            probes: [.fullDiskAccess: .denied]
        )
        let gate = PrerequisitesNavigationGate(
            configuration: PrerequisitesConfiguration(required: [.fullDiskAccess]),
            orchestrator: orchestrator
        )
        gate.refresh()
        XCTAssertEqual(gate.resolve(.home), .prerequisites)
        XCTAssertEqual(gate.resolve(.prerequisites), .prerequisites)
    }

    func testHomeAndAutomationTargetsAreInCatalog() {
        XCTAssertEqual(PermissionKind.kind(for: .home).promptKind, .settingsOnly)
        XCTAssertEqual(PermissionKind.kind(for: .automationShortcutsEvents).promptKind, .sideEffectNudge)
        XCTAssertEqual(PermissionKind.kind(for: .automationGoogleChrome).promptKind, .sideEffectNudge)
        XCTAssertEqual(PermissionKind.kind(for: .automationTextEdit).promptKind, .sideEffectNudge)
    }
}
