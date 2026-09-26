import SwiftUI
import SwiftUIX

/// Splash pulse shown until the first bootstrap refresh completes (`SLOT_PrerequisitesSplash`).
public struct PrerequisitesSplashView: View {
    public var isPulsing: Bool

    public init(isPulsing: Bool = true) {
        self.isPulsing = isPulsing
    }

    public var body: some View {
        ZStack {
            PermissionBackdrop()
            VStack(spacing: 20) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 64, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)
                    .scaleEffect(isPulsing ? 1.08 : 0.92)
                    .animation(
                        .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                        value: isPulsing
                    )
                Text("Prerequisites")
                    .font(.title.weight(.semibold))
                Text("Checking checklist…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .permissionGlassPanel()
        }
        .frame(minWidth: 480, minHeight: 360)
    }
}

/// Orca-like checklist screen — no milestones, no multi-step wizard (`SLOT_PrerequisitesChecklist`).
public struct PrerequisitesChecklistView: View {
    @Bindable public var gate: PrerequisitesNavigationGate
    @Bindable public var session: PermissionSessionController

    public init(gate: PrerequisitesNavigationGate, session: PermissionSessionController) {
        self.gate = gate
        self.session = session
    }

    public var body: some View {
        ZStack {
            PermissionBackdrop()

            GlassEffectContainer(spacing: PermissionChrome.glassSpacing) {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    checklistSection
                    if session.orchestrator.relaunchRequired {
                        QuitAndRelaunchView(session: session)
                    }
                    if let denied = session.deniedRecord {
                        DeniedRecoveryView(session: session, record: denied)
                    }
                }
                .permissionGlassPanel()
            }
            .padding(32)

            if let pending = session.pending {
                SystemPromptPendingView(pending: pending)
            }
        }
        .frame(minWidth: 720, minHeight: 560)
        .navigationTitle("Prerequisites")
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Prerequisites")
                    .font(.largeTitle.weight(.semibold))
                Text(aggregateLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                gate.refresh()
                session.refreshFromWindowKey()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.glass)
            .help("Re-probe every checklist item on demand. No background polling.")
        }
    }

    private var aggregateLabel: String {
        if gate.isChecklistSatisfied {
            return "Checklist complete — Home and other destinations are unlocked."
        }
        return "Checklist incomplete — other destinations stay disabled until every required item is granted."
    }

    private var checklistSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Checklist")
                    .font(.title2.weight(.semibold))
                Spacer()
                Image(systemName: gate.isChecklistSatisfied ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(gate.isChecklistSatisfied ? Color.green : Color.secondary)
                    .accessibilityLabel(gate.isChecklistSatisfied ? "Checklist checked" : "Checklist unchecked")
            }

            ForEach(gate.checklistItems) { record in
                PrerequisitesChecklistRow(
                    record: record,
                    session: session
                )
            }
        }
    }
}

public struct PrerequisitesChecklistRow: View {
    public let record: PermissionRecord
    @Bindable public var session: PermissionSessionController

    public init(record: PermissionRecord, session: PermissionSessionController) {
        self.record = record
        self.session = session
    }

    public var body: some View {
        let kind = PermissionKind.kind(for: record.id)
        let checked = record.authorization == .granted
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(checked ? Color.green : Color.secondary)
                .accessibilityLabel(checked ? "Checked" : "Unchecked")

            Image(systemName: PermissionChrome.symbolName(for: record.id))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(kind.systemSettingsTitle)
                    .font(.headline)
                Text(kind.purpose)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Text(PermissionChrome.statusLabel(record.authorization))
                .font(.caption.weight(.semibold))
                .foregroundStyle(PermissionChrome.statusTint(record.authorization))

            Button(PermissionSlotCopy.primaryButtonTitle(id: record.id)) {
                Task { await session.request(record.id) }
            }
            .buttonStyle(.glassProminent)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(
            .regular,
            in: RoundedRectangle(cornerRadius: PermissionChrome.rowCornerRadius, style: .continuous)
        )
    }
}

/// Host root: splash until bootstrap, then Prerequisites or Home per the gate.
public struct PrerequisitesRootView<HomeContent: View>: View {
    @Bindable public var gate: PrerequisitesNavigationGate
    @Bindable public var session: PermissionSessionController
    public var home: () -> HomeContent

    public init(
        gate: PrerequisitesNavigationGate,
        session: PermissionSessionController,
        @ViewBuilder home: @escaping () -> HomeContent
    ) {
        self.gate = gate
        self.session = session
        self.home = home
    }

    public var body: some View {
        Group {
            if gate.isBootstrapping || gate.didBootstrap == false {
                PrerequisitesSplashView(isPulsing: true)
                    .onAppear { gate.bootstrapIfNeeded() }
            } else {
                switch gate.selectedDestination {
                case .prerequisites:
                    PrerequisitesChecklistView(gate: gate, session: session)
                case .home:
                    home()
                }
            }
        }
        .onChange(of: gate.isChecklistSatisfied) { _, satisfied in
            if satisfied == false {
                _ = gate.navigate(to: .prerequisites)
            }
        }
    }
}

/// Convenience scene wrapping the Prerequisites checklist.
public struct PrerequisitesScene: Scene {
    @State private var gate: PrerequisitesNavigationGate
    @State private var session: PermissionSessionController

    public init(
        configuration: PrerequisitesConfiguration = .standard
    ) {
        let built = PrerequisitesNavigationGate(configuration: configuration)
        _gate = State(initialValue: built)
        _session = State(
            initialValue: PermissionSessionController(orchestrator: built.orchestrator)
        )
    }

    public var body: some Scene {
        Window("Prerequisites", id: "mac-permission-kit.prerequisites") {
            PrerequisitesRootView(gate: gate, session: session) {
                Text("Home")
                    .font(.largeTitle)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 860, height: 680)
    }
}
