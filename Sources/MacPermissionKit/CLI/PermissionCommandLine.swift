import Foundation

public enum PermissionCommand: Equatable, Sendable {
    case help
    case catalog
    case status(json: Bool)
    case request(PermissionID)
    case openSettings(PermissionID)
    case reset(PermissionID)
    case advance
}

public enum PermissionCommandLine {
    public static let helpText = """
    matkoson-permissions — MacPermissionKit command line

    USAGE:
      matkoson-permissions help
      matkoson-permissions catalog
      matkoson-permissions status [--json]
      matkoson-permissions request <id>
      matkoson-permissions open-settings <id>
      matkoson-permissions reset <id>
      matkoson-permissions advance

    status reads the current authorization without presenting a dialog.
    request, open-settings, reset, and advance perform the same engine actions as the library.
    """

    public static func parse(_ arguments: [String]) throws -> PermissionCommand {
        guard let command = arguments.first else {
            throw PermissionKitError.command("Missing command.\n\(helpText)")
        }
        switch command {
        case "help", "--help", "-h":
            return .help
        case "catalog":
            return .catalog
        case "status":
            let json = arguments.dropFirst().contains("--json")
            let extra = arguments.dropFirst().filter { $0 != "--json" }
            if !extra.isEmpty {
                throw PermissionKitError.command("Unexpected status argument \(extra[0]).")
            }
            return .status(json: json)
        case "request":
            return .request(try identifier(arguments))
        case "open-settings":
            return .openSettings(try identifier(arguments))
        case "reset":
            return .reset(try identifier(arguments))
        case "advance":
            if arguments.count != 1 {
                throw PermissionKitError.command("advance takes no arguments.")
            }
            return .advance
        default:
            throw PermissionKitError.command("Unknown command \(command).\n\(helpText)")
        }
    }

    public static func catalogText() -> String {
        PermissionKind.all.map { kind in
            "\(kind.id.rawValue)\t\(kind.promptKind.rawValue)\t\(kind.systemSettingsTitle)"
        }.joined(separator: "\n")
    }

    public static func statusText(snapshot: PermissionSnapshot, json: Bool) throws -> String {
        let rows = snapshot.records.map { record in
            StatusRow(
                id: record.id.rawValue,
                authorization: record.authorization.rawValue,
                title: PermissionKind.kind(for: record.id).systemSettingsTitle
            )
        }
        if json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(rows)
            return String(decoding: data, as: UTF8.self)
        }
        return rows.map { "\($0.id)\t\($0.authorization)\t\($0.title)" }.joined(separator: "\n")
    }

    
    @MainActor
    public static func execute(commandLine arguments: [String]) async -> Int32 {
        let tail = Array(arguments.dropFirst())
        do {
            let command = try parse(tail)
            switch command {
            case .help:
                print(helpText)
                return 0
            case .catalog:
                print(catalogText())
                return 0
            case .status(let json):
                let session = PermissionOrchestrator(required: PermissionKind.startupDefaultOrder)
                session.refresh()
                print(try statusText(snapshot: session.snapshot, json: json))
                return 0
            case .request(let id):
                let session = PermissionOrchestrator(required: PermissionKind.startupDefaultOrder)
                let result = await session.request(id)
                print("\(id.rawValue)\t\(result.record.authorization.rawValue)")
                return 0
            case .openSettings(let id):
                let session = PermissionOrchestrator(required: PermissionKind.startupDefaultOrder)
                let result = await session.openSettings(id)
                print("\(id.rawValue)\tsettingsOpened=\(result.settingsOpened)")
                return 0
            case .reset(let id):
                let session = PermissionOrchestrator(required: PermissionKind.startupDefaultOrder)
                try session.reset(id)
                print("\(id.rawValue)\treset")
                return 0
            case .advance:
                let session = PermissionOrchestrator(required: PermissionKind.startupDefaultOrder)
                if let result = await session.advanceStartup() {
                    print("\(result.record.id.rawValue)\t\(result.record.authorization.rawValue)")
                } else {
                    print("satisfied")
                }
                return 0
            }
        } catch {
            FileHandle.standardError.write(Data("\(error)\n".utf8))
            return 2
        }
    }

    private static func identifier(_ arguments: [String]) throws -> PermissionID {
        guard arguments.count >= 2 else {
            throw PermissionKitError.command("Missing permission id.")
        }
        if arguments.count > 2 {
            throw PermissionKitError.command("Unexpected argument \(arguments[2]).")
        }
        guard let id = PermissionID(rawValue: arguments[1]) else {
            throw PermissionKitError.command("Unknown permission id \(arguments[1]).")
        }
        return id
    }
}

private struct StatusRow: Codable {
    var id: String
    var authorization: String
    var title: String
}
