import Foundation

/// Destinations the host sidebar may expose. Only `prerequisites` stays enabled while incomplete.
public enum PrerequisitesDestination: String, Sendable, Codable, Hashable, CaseIterable {
    case prerequisites
    case home
}

/// One sidebar row the host can render from the gate without inventing its own policy.
public struct PrerequisitesSidebarItem: Sendable, Hashable, Identifiable {
    public enum Kind: String, Sendable, Codable, Hashable {
        case destination
        case divider
    }

    public let id: String
    public let kind: Kind
    public let destination: PrerequisitesDestination?
    public let title: String?
    public let isEnabled: Bool

    public init(
        id: String,
        kind: Kind,
        destination: PrerequisitesDestination? = nil,
        title: String? = nil,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.kind = kind
        self.destination = destination
        self.title = title
        self.isEnabled = isEnabled
    }
}

/// Aggregate checklist + navigation policy shared by every host.
/// Checked iff every required item is granted; otherwise unchecked and all non-Prerequisites
/// destinations are disabled / redirected.
@MainActor
@Observable
public final class PrerequisitesNavigationGate {
    public private(set) var orchestrator: PermissionOrchestrator
    public private(set) var configuration: PrerequisitesConfiguration
    public private(set) var selectedDestination: PrerequisitesDestination
    /// True until the first bootstrap `refresh()` finishes (splash pulse).
    public private(set) var isBootstrapping: Bool
    public private(set) var didBootstrap: Bool

    public init(
        configuration: PrerequisitesConfiguration = .standard,
        orchestrator: PermissionOrchestrator? = nil
    ) {
        let config = configuration
        let session = orchestrator ?? PermissionOrchestrator(
            required: config.required,
            policy: config.presentationPolicy
        )
        self.configuration = config
        self.orchestrator = session
        self.isBootstrapping = true
        self.didBootstrap = false
        self.selectedDestination = .prerequisites
    }

    /// Aggregate checklist state: checked only when every required item is granted.
    public var isChecklistSatisfied: Bool {
        orchestrator.allRequiredSatisfied
    }

    public var checklistItems: [PermissionRecord] {
        configuration.required.map { orchestrator.snapshot.record(for: $0) }
    }

    /// Prerequisites first, horizontal divider, then Home (disabled until satisfied).
    public var sidebarItems: [PrerequisitesSidebarItem] {
        let unlocked = isChecklistSatisfied
        return [
            PrerequisitesSidebarItem(
                id: "prerequisites",
                kind: .destination,
                destination: .prerequisites,
                title: "Prerequisites",
                isEnabled: true
            ),
            PrerequisitesSidebarItem(
                id: "divider-before-home",
                kind: .divider
            ),
            PrerequisitesSidebarItem(
                id: "home",
                kind: .destination,
                destination: .home,
                title: "Home",
                isEnabled: unlocked
            ),
        ]
    }

    public func isEnabled(_ destination: PrerequisitesDestination) -> Bool {
        switch destination {
        case .prerequisites:
            return true
        case .home:
            return isChecklistSatisfied
        }
    }

    /// Hosts call this for any navigation attempt. Incomplete → always Prerequisites.
    @discardableResult
    public func navigate(to destination: PrerequisitesDestination) -> PrerequisitesDestination {
        let resolved = resolve(destination)
        selectedDestination = resolved
        return resolved
    }

    /// Where a host should land after splash bootstrap (or after a later refresh).
    public func landingDestination() -> PrerequisitesDestination {
        isChecklistSatisfied ? .home : .prerequisites
    }

    public func resolve(_ destination: PrerequisitesDestination) -> PrerequisitesDestination {
        if isChecklistSatisfied == false {
            return .prerequisites
        }
        return destination
    }

    /// Re-probe every permission. No background polling — hosts call this from Refresh / splash.
    public func refresh() {
        orchestrator.refresh()
        if isChecklistSatisfied == false, selectedDestination != .prerequisites {
            selectedDestination = .prerequisites
        } else if didBootstrap == false {
            selectedDestination = landingDestination()
        } else if isChecklistSatisfied, selectedDestination == .prerequisites {
            // Stay on Prerequisites until the user navigates; do not auto-jump after mid-session refresh.
        }
        if isBootstrapping {
            isBootstrapping = false
            didBootstrap = true
            selectedDestination = landingDestination()
        }
    }

    public func bootstrapIfNeeded() {
        guard didBootstrap == false else { return }
        isBootstrapping = true
        refresh()
    }
}
