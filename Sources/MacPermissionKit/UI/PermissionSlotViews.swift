import SwiftUI
import SwiftUIX

/// Cover while a system TCC dialog is visible (`SLOT_SystemPromptPending`).
public struct SystemPromptPendingView: View {
    public var pending: PermissionID

    public init(pending: PermissionID) {
        self.pending = pending
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)
                Text(PermissionSlotCopy.waitingForPrompt(id: pending))
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text("Complete the system dialog, then return here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(28)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .frame(maxWidth: 360)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Deep-link control (`SLOT_OpenSettingsCTA`).
public struct OpenSettingsCTAView: View {
    public var id: PermissionID
    public var session: PermissionSessionController
    public var title: String

    public init(
        id: PermissionID,
        session: PermissionSessionController,
        title: String = "Open Settings"
    ) {
        self.id = id
        self.session = session
        self.title = title
    }

    public var body: some View {
        Button(title) {
            Task { await session.openSettings(for: id) }
        }
        .buttonStyle(.glass)
        .help("Opens the matching Privacy & Security pane in System Settings.")
    }
}

/// Coach mark for drag-into-list permissions (`SLOT_DragIntoListHint`).
public struct DragIntoListHintView: View {
    public var permissionID: PermissionID
    public var bundleName: String

    public init(permissionID: PermissionID, bundleName: String? = nil) {
        self.permissionID = permissionID
        self.bundleName = bundleName ?? PermissionChrome.appDisplayName
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "hand.draw.fill")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(PermissionSlotCopy.dragIntoListHint(bundleName: bundleName, id: permissionID))
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ConcentricRectangle()
                .fill(.quaternary.opacity(0.35))
        }
        .glassEffect(.regular, in: ConcentricRectangle())
    }
}

/// Shown when `orchestrator.relaunchRequired` (`SLOT_QuitAndRelaunch`).
public struct QuitAndRelaunchView: View {
    public var session: PermissionSessionController

    public init(session: PermissionSessionController) {
        self.session = session
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quit and reopen")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Quit Now") {
                session.quitNow()
            }
            .buttonStyle(.glassProminent)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var message: String {
        let id = session.focusedID ?? session.orchestrator.lastResult?.record.id ?? .screenRecording
        let title = PermissionKind.kind(for: id).systemSettingsTitle
        return "\(title) usually binds only after this process exits. Quit, reopen the app, then continue."
    }
}

/// After a denied / restricted prompt (`SLOT_DeniedRecovery`).
public struct DeniedRecoveryView: View {
    public var session: PermissionSessionController
    public var record: PermissionRecord

    public init(session: PermissionSessionController, record: PermissionRecord) {
        self.session = session
        self.record = record
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(PermissionKind.kind(for: record.id).systemSettingsTitle) was not granted")
                .font(.headline)
            Text("Open System Settings to enable it, or continue without this permission if it is optional.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                if session.orchestrator.policy.optionalIDs.contains(record.id) {
                    Button("Continue Without") {
                        session.skipCurrent()
                    }
                    .buttonStyle(.glass)
                }
                Button("Open Settings") {
                    Task { await session.openSettingsForSelection() }
                }
                .buttonStyle(.glassProminent)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// All required IDs granted or optional skips applied (`SLOT_Completion`).
public struct CompletionView: View {
    public var session: PermissionSessionController

    public init(session: PermissionSessionController) {
        self.session = session
    }

    public var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 44))
                .foregroundStyle(.green)
                .glassEffect(.regular.interactive(), in: Circle())
            Text("Permissions ready")
                .font(.title2.weight(.semibold))
            Text("You can keep adjusting grants later from Settings.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Done") {
                session.finishOnboarding()
            }
            .buttonStyle(.glassProminent)
            .keyboardShortcut(.defaultAction)
        }
        .padding(32)
        .permissionGlassPanel()
    }
}

/// Settings pane listing tracked permissions.
public struct PermissionSettingsPane: View {
    @Bindable public var session: PermissionSessionController

    public init(session: PermissionSessionController) {
        self.session = session
    }

    public var body: some View {
        NavigationStack {
            PermissionListView(session: session, showsOnlyStartup: false)
                .navigationTitle("Privacy")
        }
        .frame(minWidth: 560, minHeight: 420)
    }
}

/// Convenience first-run scene.
public struct PermissionStartupScene: Scene {
    @State private var session: PermissionSessionController

    public init(session: PermissionSessionController = PermissionSessionController()) {
        _session = State(initialValue: session)
    }

    public var body: some Scene {
        Window("Permissions", id: "mac-permission-kit.startup") {
            StartupGlassShellView(session: session)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 820, height: 640)
        .windowResizability(.contentSize)
    }
}
