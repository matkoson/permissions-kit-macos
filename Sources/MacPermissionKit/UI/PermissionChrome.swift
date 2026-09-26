import AppKit
import SwiftUI
import SwiftUIX

enum PermissionChrome {
    static let panelCornerRadius: CGFloat = 28
    static let rowCornerRadius: CGFloat = 16
    static let glassSpacing: CGFloat = 24

    static func statusLabel(_ authorization: PermissionAuthorization) -> String {
        switch authorization {
        case .granted: "Granted"
        case .denied: "Denied"
        case .restricted: "Restricted"
        case .notDetermined: "Not Determined"
        case .unknown: "Unknown"
        case .unsupported: "Unsupported"
        }
    }

    static func statusTint(_ authorization: PermissionAuthorization) -> Color {
        switch authorization {
        case .granted: .green
        case .denied, .restricted: .orange
        case .notDetermined, .unknown, .unsupported: .secondary
        }
    }

    static func symbolName(for id: PermissionID) -> String {
        switch id {
        case .camera: "camera.fill"
        case .microphone: "mic.fill"
        case .screenRecording: "rectangle.inset.filled.and.person.filled"
        case .systemAudioCapture: "waveform"
        case .speech: "waveform.badge.mic"
        case .accessibility: "accessibility"
        case .inputMonitoring: "keyboard"
        case .automation, .automationShortcutsEvents, .automationTestFlight,
             .automationGoogleChrome, .automationTextEdit:
            "applescript"
        case .fullDiskAccess: "internaldrive.fill"
        case .desktopFolder, .documentsFolder, .downloadsFolder: "folder.fill"
        case .removableVolumes, .networkVolumes: "externaldrive.fill"
        case .localNetwork: "network"
        case .bluetooth: "antenna.radiowaves.left.and.right"
        case .usb: "cable.connector"
        case .location: "location.fill"
        case .contacts: "person.crop.circle"
        case .calendars: "calendar"
        case .reminders: "checklist"
        case .photos, .photosAddOnly: "photo"
        case .mediaLibrary: "music.note.list"
        case .home: "home.fill"
        case .notifications: "bell.fill"
        case .developerTools: "hammer.fill"
        case .appManagement: "app.badge.fill"
        }
    }

    static var appDisplayName: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? "this app"
    }
}

extension View {
    @ViewBuilder
    func permissionGlassPanel() -> some View {
        self
            .padding(24)
            .frame(maxWidth: 720)
            .glassEffect(
                .regular,
                in: RoundedRectangle(cornerRadius: PermissionChrome.panelCornerRadius, style: .continuous)
            )
            .containerShape(
                RoundedRectangle(cornerRadius: PermissionChrome.panelCornerRadius, style: .continuous)
            )
    }
}

struct PermissionVisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .underWindowBackground
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = .active
    }
}

/// Desktop-backed blur; SwiftUIX `WindowReader` keeps the host window frontmost for TCC.
struct PermissionBackdrop: View {
    var body: some View {
        WindowReader { proxy in
            ZStack {
                PermissionVisualEffectBackground()
                LinearGradient(
                    colors: [
                        Color.accentColor.opacity(0.18),
                        Color.clear,
                        Color.primary.opacity(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .ignoresSafeArea()
            .onAppear { proxy.orderFrontRegardless() }
        }
    }
}
