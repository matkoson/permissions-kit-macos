import SwiftUI
import SwiftUIX

/// Roster of permissions (`SLOT_PermissionList`).
public struct PermissionListView: View {
    @Bindable public var session: PermissionSessionController
    public var showsOnlyStartup: Bool

    public init(session: PermissionSessionController, showsOnlyStartup: Bool = true) {
        self.session = session
        self.showsOnlyStartup = showsOnlyStartup
    }

    public var body: some View {
        List(selection: selectedBinding) {
            ForEach(displayedRecords) { record in
                PermissionRowView(
                    record: record,
                    session: session,
                    emphasized: session.selectedID == record.id
                )
                .tag(record.id)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .background {
            PermissionVisualEffectBackground(
                material: .contentBackground,
                blendingMode: .withinWindow
            )
        }
        .onAppear { session.refreshFromWindowKey() }
    }

    private var displayedRecords: [PermissionRecord] {
        if showsOnlyStartup {
            return session.records
        }
        return session.orchestrator.snapshot.records
    }

    private var selectedBinding: Binding<PermissionID?> {
        Binding(
            get: { session.selectedID },
            set: { newValue in
                if let newValue {
                    session.select(newValue)
                }
            }
        )
    }
}

/// One permission row (`SLOT_PermissionRow`).
public struct PermissionRowView: View {
    public let record: PermissionRecord
    @Bindable public var session: PermissionSessionController
    public var emphasized: Bool

    public init(
        record: PermissionRecord,
        session: PermissionSessionController,
        emphasized: Bool = false
    ) {
        self.record = record
        self.session = session
        self.emphasized = emphasized
    }

    public var body: some View {
        let kind = PermissionKind.kind(for: record.id)
        GlassEffectContainer(spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                Image(systemName: PermissionChrome.symbolName(for: record.id))
                    .font(.title2)
                    .frame(width: 36, height: 36)
                    .glassEffect(.regular.interactive(), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(kind.systemSettingsTitle)
                        .font(.headline)
                    Text(kind.purpose)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(PermissionChrome.statusLabel(record.authorization))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PermissionChrome.statusTint(record.authorization))
                }

                Spacer(minLength: 12)

                HStack(spacing: 8) {
                    if kind.primarySettingsURL != nil {
                        Button("Open Settings") {
                            Task { await session.openSettings(for: record.id) }
                        }
                        .buttonStyle(.glass)
                    }

                    Button(PermissionSlotCopy.primaryButtonTitle(id: record.id)) {
                        Task { await session.request(record.id) }
                    }
                    .buttonStyle(.glassProminent)
                }
            }
            .padding(emphasized ? 18 : 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(
                emphasized ? .regular.interactive() : .regular,
                in: RoundedRectangle(cornerRadius: PermissionChrome.rowCornerRadius, style: .continuous)
            )
        }
        .contentShape(RoundedRectangle(cornerRadius: PermissionChrome.rowCornerRadius, style: .continuous))
        .onTapGesture { session.select(record.id) }
    }
}
