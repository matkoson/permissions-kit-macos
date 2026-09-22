import AppKit
import SwiftUI
import SwiftUIX

/// Full-window first-run chrome (`SLOT_StartupGlassShell`).
public struct StartupGlassShellView: View {
    @Bindable public var session: PermissionSessionController
    @Namespace private var glassNamespace

    public init(session: PermissionSessionController) {
        self.session = session
    }

    public var body: some View {
        ZStack {
            PermissionBackdrop()

            GlassEffectContainer(spacing: PermissionChrome.glassSpacing) {
                VStack(spacing: 28) {
                    header
                    progress
                    focusCard
                    if let id = session.focusedID, PermissionSlotCopy.showsDragHint(id: id) {
                        DragIntoListHintView(permissionID: id)
                            .glassEffectID("drag-hint", in: glassNamespace)
                    }
                    if session.orchestrator.relaunchRequired {
                        QuitAndRelaunchView(session: session)
                            .glassEffectID("relaunch", in: glassNamespace)
                    }
                    if let denied = session.deniedRecord {
                        DeniedRecoveryView(session: session, record: denied)
                            .glassEffectID("denied", in: glassNamespace)
                    }
                    actions
                }
                .permissionGlassPanel()
                .glassEffectID("shell", in: glassNamespace)
            }
            .padding(40)

            if let pending = session.pending {
                SystemPromptPendingView(pending: pending)
                    .transition(.opacity)
            }

            if session.didFinishOnboarding || (session.canDismiss && session.orchestrator.allRequiredSatisfied) {
                CompletionView(session: session)
                    .transition(.opacity)
            }
        }
        .frame(minWidth: 720, minHeight: 520)
        .onAppear { session.presentStartup() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            session.refreshFromWindowKey()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Permissions")
                .font(.largeTitle.weight(.semibold))
            Text(subtitle)
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var subtitle: String {
        if let kind = session.focusedKind {
            return "Allow \(kind.systemSettingsTitle) so this Mac can \(kind.purpose.lowercased())"
        }
        return "All required permissions are ready."
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProgressView(value: session.progress)
                .progressViewStyle(.linear)
            Text("\(Int((session.progress * 100).rounded()))% ready")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var focusCard: some View {
        if let id = session.focusedID {
            PermissionRowView(
                record: session.orchestrator.snapshot.record(for: id),
                session: session,
                emphasized: true
            )
            .glassEffectID(id.rawValue, in: glassNamespace)
        } else {
            Text("You’re all set.")
                .font(.title2.weight(.medium))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var actions: some View {
        HStack(spacing: 12) {
            if let id = session.focusedID, session.orchestrator.policy.optionalIDs.contains(id) {
                Button("Skip for Now") {
                    session.select(id)
                    session.skipCurrent()
                }
                .buttonStyle(.glass)
            }

            Button(session.canDismiss ? "Continue" : primaryTitle) {
                Task {
                    if session.canDismiss {
                        session.finishOnboarding()
                    } else {
                        await session.advance()
                    }
                }
            }
            .buttonStyle(.glassProminent)
            .keyboardShortcut(.defaultAction)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var primaryTitle: String {
        guard let id = session.focusedID else { return "Continue" }
        return PermissionSlotCopy.primaryButtonTitle(id: id)
    }
}
