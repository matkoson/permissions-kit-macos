import Foundation

public enum PermissionCommand: Equatable, Sendable {
    case help
    case catalog
    case status(json: Bool)
    case checklist(json: Bool)
    case gate(json: Bool)
    case refresh(json: Bool)
    case request(PermissionID)
    case openSettings(PermissionID)
    case reset(PermissionID, bundleIdentifier: String?)
    case advance
}

public enum PermissionCommandLine {
    public static let helpText = """
    matkoson-permissions — MacPermissionKit / Prerequisites command line

    USAGE:
      matkoson-permissions help
      matkoson-permissions catalog
      matkoson-permissions status [--json]
      matkoson-permissions checklist [--json]
      matkoson-permissions gate [--json]
      matkoson-permissions refresh [--json]
      matkoson-permissions request <id>
      matkoson-permissions open-settings <id>
      matkoson-permissions reset <id> [bundle-id]
      matkoson-permissions advance

    checklist / gate / refresh use the shared Prerequisites default matrix.
    refresh re-probes on demand (no background polling).
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
            return .status(json: try flagJSON(arguments))
        case "checklist":
            return .checklist(json: try flagJSON(arguments))
        case "gate":
            return .gate(json: try flagJSON(arguments))
        case "refresh":
            return .refresh(json: try flagJSON(arguments))
        case "request":
            return .request(try identifier(arguments).id)
        case "open-settings":
            return .openSettings(try identifier(arguments).id)
        case "reset":
            let parsed = try identifier(arguments, extra: .bundleIdentifier)
            return .reset(parsed.id, bundleIdentifier: parsed.bundleIdentifier)
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
            return try encodeJSON(rows)
        }
        return rows.map { "\($0.id)\t\($0.authorization)\t\($0.title)" }.joined(separator: "\n")
    }

    public static func checklistText(
        items: [PermissionRecord],
        satisfied: Bool,
        json: Bool
    ) throws -> String {
        let rows = items.map { record in
            ChecklistRow(
                id: record.id.rawValue,
                authorization: record.authorization.rawValue,
                checked: record.authorization == .granted,
                title: PermissionKind.kind(for: record.id).systemSettingsTitle
            )
        }
        let payload = ChecklistPayload(satisfied: satisfied, items: rows)
        if json {
            return try encodeJSON(payload)
        }
        var lines = ["checklist\t\(satisfied ? "checked" : "unchecked")"]
        lines.append(contentsOf: rows.map {
            "\($0.id)\t\($0.checked ? "checked" : "unchecked")\t\($0.authorization)\t\($0.title)"
        })
        return lines.joined(separator: "\n")
    }

    public static func gateText(
        satisfied: Bool,
        landing: PrerequisitesDestination,
        sidebar: [PrerequisitesSidebarItem],
        json: Bool
    ) throws -> String {
        let payload = GatePayload(
            satisfied: satisfied,
            landing: landing.rawValue,
            sidebar: sidebar.map {
                GateSidebarRow(
                    id: $0.id,
                    kind: $0.kind.rawValue,
                    destination: $0.destination?.rawValue,
                    title: $0.title,
                    enabled: $0.isEnabled
                )
            }
        )
        if json {
            return try encodeJSON(payload)
        }
        var lines = [
            "satisfied\t\(satisfied)",
            "landing\t\(landing.rawValue)",
        ]
        for item in sidebar {
            switch item.kind {
            case .divider:
                lines.append("divider\t\(item.id)")
            case .destination:
                lines.append(
                    "item\t\(item.destination?.rawValue ?? "?")\t\(item.isEnabled ? "enabled" : "disabled")\t\(item.title ?? "")"
                )
            }
        }
        return lines.joined(separator: "\n")
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
                let session = PermissionOrchestrator(
                    required: PermissionKind.prerequisitesDefaultRequired,
                    policy: .standard
                )
                session.refresh()
                print(try statusText(snapshot: session.snapshot, json: json))
                return 0
            case .checklist(let json):
                let gate = PrerequisitesNavigationGate()
                gate.refresh()
                print(try checklistText(
                    items: gate.checklistItems,
                    satisfied: gate.isChecklistSatisfied,
                    json: json
                ))
                return 0
            case .gate(let json):
                let gate = PrerequisitesNavigationGate()
                gate.refresh()
                print(try gateText(
                    satisfied: gate.isChecklistSatisfied,
                    landing: gate.landingDestination(),
                    sidebar: gate.sidebarItems,
                    json: json
                ))
                return 0
            case .refresh(let json):
                let gate = PrerequisitesNavigationGate()
                gate.refresh()
                print(try checklistText(
                    items: gate.checklistItems,
                    satisfied: gate.isChecklistSatisfied,
                    json: json
                ))
                return 0
            case .request(let id):
                let session = PermissionOrchestrator(
                    required: PermissionKind.prerequisitesDefaultRequired,
                    policy: .standard
                )
                let result = await session.request(id)
                print("\(id.rawValue)\t\(result.record.authorization.rawValue)")
                return 0
            case .openSettings(let id):
                let session = PermissionOrchestrator(
                    required: PermissionKind.prerequisitesDefaultRequired,
                    policy: .standard
                )
                let result = await session.openSettings(id)
                print("\(id.rawValue)\tsettingsOpened=\(result.settingsOpened)")
                return 0
            case .reset(let id, let bundleIdentifier):
                let session = PermissionOrchestrator(
                    required: PermissionKind.prerequisitesDefaultRequired,
                    policy: .standard,
                    bundleIdentifier: bundleIdentifier ?? Bundle.main.bundleIdentifier
                )
                try session.reset(id)
                print("\(id.rawValue)\treset")
                return 0
            case .advance:
                let session = PermissionOrchestrator(
                    required: PermissionKind.prerequisitesDefaultRequired,
                    policy: .standard
                )
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

    private enum ExtraArgument {
        case forbidden
        case bundleIdentifier
    }

    private static func flagJSON(_ arguments: [String]) throws -> Bool {
        let json = arguments.dropFirst().contains("--json")
        let extra = arguments.dropFirst().filter { $0 != "--json" }
        if let first = extra.first {
            throw PermissionKitError.command("Unexpected argument \(first).")
        }
        return json
    }

    private static func identifier(
        _ arguments: [String],
        extra: ExtraArgument = .forbidden
    ) throws -> (id: PermissionID, bundleIdentifier: String?) {
        guard arguments.count >= 2 else {
            throw PermissionKitError.command("Missing permission id.")
        }
        let bundleIdentifier: String?
        switch extra {
        case .forbidden:
            if arguments.count > 2 {
                throw PermissionKitError.command("Unexpected argument \(arguments[2]).")
            }
            bundleIdentifier = nil
        case .bundleIdentifier:
            if arguments.count > 3 {
                throw PermissionKitError.command("Unexpected argument \(arguments[3]).")
            }
            bundleIdentifier = arguments.count == 3 ? arguments[2] : nil
        }
        guard let id = PermissionID(rawValue: arguments[1]) else {
            throw PermissionKitError.command("Unknown permission id \(arguments[1]).")
        }
        return (id, bundleIdentifier)
    }

    private static func encodeJSON<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        return String(decoding: data, as: UTF8.self)
    }
}

private struct StatusRow: Codable {
    var id: String
    var authorization: String
    var title: String
}

private struct ChecklistRow: Codable {
    var id: String
    var authorization: String
    var checked: Bool
    var title: String
}

private struct ChecklistPayload: Codable {
    var satisfied: Bool
    var items: [ChecklistRow]
}

private struct GateSidebarRow: Codable {
    var id: String
    var kind: String
    var destination: String?
    var title: String?
    var enabled: Bool
}

private struct GatePayload: Codable {
    var satisfied: Bool
    var landing: String
    var sidebar: [GateSidebarRow]
}
