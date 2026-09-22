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
        XCTAssertTrue(PermissionCommandLine.helpText.contains("reset"))
    }

    func testErrorDescriptions() {
        XCTAssertTrue(PermissionKitError.resetUnsupported(.usb).description.contains("usb"))
        XCTAssertTrue(PermissionKitError.resetFailed(.camera, 3).description.contains("3"))
        XCTAssertTrue(PermissionKitError.skipNotAllowed(.microphone).description.contains("microphone"))
        XCTAssertEqual(PermissionKitError.backend("empty command").description, "empty command")
        XCTAssertEqual(PermissionKitError.command("nope").description, "nope")
    }
}
