import XCTest
@testable import MacPermissionKit

final class CLITests: XCTestCase {
    func testParseCommands() throws {
        XCTAssertEqual(try PermissionCommandLine.parse(["help"]), .help)
        XCTAssertEqual(try PermissionCommandLine.parse(["--help"]), .help)
        XCTAssertEqual(try PermissionCommandLine.parse(["-h"]), .help)
        XCTAssertEqual(try PermissionCommandLine.parse(["catalog"]), .catalog)
        XCTAssertEqual(try PermissionCommandLine.parse(["status"]), .status(json: false))
        XCTAssertEqual(try PermissionCommandLine.parse(["status", "--json"]), .status(json: true))
        XCTAssertEqual(try PermissionCommandLine.parse(["checklist"]), .checklist(json: false))
        XCTAssertEqual(try PermissionCommandLine.parse(["checklist", "--json"]), .checklist(json: true))
        XCTAssertEqual(try PermissionCommandLine.parse(["gate"]), .gate(json: false))
        XCTAssertEqual(try PermissionCommandLine.parse(["refresh", "--json"]), .refresh(json: true))
        XCTAssertEqual(try PermissionCommandLine.parse(["request", "microphone"]), .request(.microphone))
        XCTAssertEqual(try PermissionCommandLine.parse(["open-settings", "fullDiskAccess"]), .openSettings(.fullDiskAccess))
        XCTAssertEqual(
            try PermissionCommandLine.parse(["reset", "screenRecording"]),
            .reset(.screenRecording, bundleIdentifier: nil)
        )
        XCTAssertEqual(
            try PermissionCommandLine.parse(["reset", "screenRecording", "app.example.kit"]),
            .reset(.screenRecording, bundleIdentifier: "app.example.kit")
        )
        XCTAssertEqual(try PermissionCommandLine.parse(["advance"]), .advance)
    }

    func testParseErrors() {
        XCTAssertThrowsError(try PermissionCommandLine.parse([]))
        XCTAssertThrowsError(try PermissionCommandLine.parse(["nope"]))
        XCTAssertThrowsError(try PermissionCommandLine.parse(["request"]))
        XCTAssertThrowsError(try PermissionCommandLine.parse(["request", "not-a-permission"]))
        XCTAssertThrowsError(try PermissionCommandLine.parse(["request", "camera", "extra"]))
        XCTAssertThrowsError(try PermissionCommandLine.parse(["advance", "extra"]))
        XCTAssertThrowsError(try PermissionCommandLine.parse(["status", "--pretty"]))
    }

    func testCatalogAndStatusRendering() throws {
        let catalog = PermissionCommandLine.catalogText()
        XCTAssertTrue(catalog.contains("screenRecording"))
        XCTAssertTrue(catalog.contains("systemPrompt"))
        let snapshot = PermissionSnapshot(records: [
            PermissionRecord(id: .microphone, authorization: .denied),
        ])
        let text = try PermissionCommandLine.statusText(snapshot: snapshot, json: false)
        XCTAssertTrue(text.contains("microphone\tdenied\tMicrophone"))
        let json = try PermissionCommandLine.statusText(snapshot: snapshot, json: true)
        XCTAssertTrue(json.contains("\"authorization\" : \"denied\""))
    }

    func testExecuteHelpAndCatalog() async {
        let help = await PermissionCommandLine.execute(commandLine: ["matkoson-permissions", "help"])
        XCTAssertEqual(help, 0)
        let catalog = await PermissionCommandLine.execute(commandLine: ["matkoson-permissions", "catalog"])
        XCTAssertEqual(catalog, 0)
        let missing = await PermissionCommandLine.execute(commandLine: ["matkoson-permissions"])
        XCTAssertEqual(missing, 2)
        let unknown = await PermissionCommandLine.execute(commandLine: ["matkoson-permissions", "nope"])
        XCTAssertEqual(unknown, 2)
    }

    func testHelpMentionsBinary() {
        XCTAssertTrue(PermissionCommandLine.helpText.contains("matkoson-permissions"))
        XCTAssertTrue(PermissionCommandLine.helpText.contains("status"))
        XCTAssertTrue(PermissionCommandLine.helpText.contains("checklist"))
        XCTAssertTrue(PermissionCommandLine.helpText.contains("gate"))
        XCTAssertTrue(PermissionCommandLine.helpText.contains("refresh"))
        XCTAssertTrue(PermissionCommandLine.helpText.contains("reset"))
    }

    func testChecklistAndGateRendering() throws {
        let items = [
            PermissionRecord(id: .fullDiskAccess, authorization: .granted),
            PermissionRecord(id: .accessibility, authorization: .denied),
        ]
        let text = try PermissionCommandLine.checklistText(items: items, satisfied: false, json: false)
        XCTAssertTrue(text.contains("checklist\tunchecked"))
        XCTAssertTrue(text.contains("fullDiskAccess\tchecked"))
        XCTAssertTrue(text.contains("accessibility\tunchecked"))
        let gate = try PermissionCommandLine.gateText(
            satisfied: false,
            landing: .prerequisites,
            sidebar: [
                PrerequisitesSidebarItem(
                    id: "prerequisites",
                    kind: .destination,
                    destination: .prerequisites,
                    title: "Prerequisites",
                    isEnabled: true
                ),
                PrerequisitesSidebarItem(id: "divider", kind: .divider),
                PrerequisitesSidebarItem(
                    id: "home",
                    kind: .destination,
                    destination: .home,
                    title: "Home",
                    isEnabled: false
                ),
            ],
            json: false
        )
        XCTAssertTrue(gate.contains("landing\tprerequisites"))
        XCTAssertTrue(gate.contains("item\thome\tdisabled\tHome"))
        XCTAssertTrue(gate.contains("divider\tdivider"))
    }

    func testExecuteChecklistGateRefreshStatus() async {
        let checklist = await PermissionCommandLine.execute(
            commandLine: ["matkoson-permissions", "checklist"]
        )
        XCTAssertEqual(checklist, 0)
        let gate = await PermissionCommandLine.execute(
            commandLine: ["matkoson-permissions", "gate", "--json"]
        )
        XCTAssertEqual(gate, 0)
        let refresh = await PermissionCommandLine.execute(
            commandLine: ["matkoson-permissions", "refresh"]
        )
        XCTAssertEqual(refresh, 0)
        let status = await PermissionCommandLine.execute(
            commandLine: ["matkoson-permissions", "status", "--json"]
        )
        XCTAssertEqual(status, 0)
        let advance = await PermissionCommandLine.execute(
            commandLine: ["matkoson-permissions", "advance"]
        )
        XCTAssertEqual(advance, 0)
    }

    func testConfigurationPresentationPolicy() {
        let config = PrerequisitesConfiguration.standard
        XCTAssertEqual(config.presentationPolicy.startupIDs, config.required)
        XCTAssertTrue(config.presentationPolicy.optionalIDs.isEmpty)
        XCTAssertTrue(PermissionID.automation.isAutomationTarget)
        XCTAssertFalse(PermissionID.microphone.isAutomationTarget)
        XCTAssertNil(PermissionID.camera.automationTargetName)
    }

    func testExecuteRequestOpenSettingsAndReset() async {
        let request = await PermissionCommandLine.execute(
            commandLine: ["matkoson-permissions", "request", "usb"]
        )
        XCTAssertEqual(request, 0)
        let open = await PermissionCommandLine.execute(
            commandLine: ["matkoson-permissions", "open-settings", "fullDiskAccess"]
        )
        XCTAssertEqual(open, 0)
        let reset = await PermissionCommandLine.execute(
            commandLine: ["matkoson-permissions", "reset", "usb", "app.example.kit"]
        )
        // usb has no tcc service → nonzero
        XCTAssertEqual(reset, 2)
    }

    func testErrorDescriptions() {
        XCTAssertTrue(PermissionKitError.resetUnsupported(.usb).description.contains("usb"))
        XCTAssertTrue(PermissionKitError.resetFailed(.camera, 3).description.contains("3"))
        XCTAssertTrue(PermissionKitError.skipNotAllowed(.microphone).description.contains("microphone"))
        XCTAssertEqual(PermissionKitError.backend("empty command").description, "empty command")
        XCTAssertEqual(PermissionKitError.command("nope").description, "nope")
    }
}
