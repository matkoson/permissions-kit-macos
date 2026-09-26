# MacPermissionKit / Prerequisites

Swift 6 permission engine for macOS 26+ with a shared **Prerequisites** checklist + navigation gate so every Matkoson GUI app configures this package only — no per-app UI forks.

Requires Swift 6.2+ and macOS 26+.

## Host configure-only recipe

```swift
import MacPermissionKit
import SwiftUI

@main
struct HostApp: App {
    @State private var gate = PrerequisitesNavigationGate(
        configuration: .standard
        // routine-worker / control / automation:
        // configuration: .withAppManagement
    )
    @State private var session = PermissionSessionController(
        configuration: .standard
    )

    var body: some Scene {
        WindowGroup {
            PrerequisitesRootView(gate: gate, session: session) {
                Text("Home")
            }
            .onAppear {
                // Share one orchestrator in production hosts:
                // build gate first, then PermissionSessionController(orchestrator: gate.orchestrator)
            }
        }
    }
}
```

Preferred production wiring (one orchestrator):

```swift
let configuration = PrerequisitesConfiguration.standard // or .withAppManagement
let gate = PrerequisitesNavigationGate(configuration: configuration)
let session = PermissionSessionController(orchestrator: gate.orchestrator)

// Sidebar: gate.sidebarItems
//   1) Prerequisites (always enabled)
//   2) horizontal divider
//   3) Home (enabled iff checklist satisfied)
// Any navigate(to:) while incomplete → .prerequisites
// After Refresh, if a required item fails → forced back to Prerequisites
```

| Surface | Role |
|---|---|
| Screen title | **Prerequisites** |
| Section title | **Checklist** (not Getting Started / Quick Setup) |
| Aggregate state | Checked iff **all** required items granted; else unchecked |
| Refresh | Circular-arrow **Refresh** button — on-demand re-probe only (no polling daemon) |
| Splash | Pulse until first bootstrap refresh; then Prerequisites if incomplete else Home |

### Default required matrix (all apps)

- Full Disk Access
- Device Control and Data Access (Accessibility)
- Developer Tools
- Calendar
- Home / HomeKit
- Media & Apple Music (`mediaLibrary`)
- Reminders
- Automation: System Events, Shortcuts Events, TestFlight.app, Google Chrome.app, TextEdit.app

**App Management** is off by default. Enable with `PrerequisitesConfiguration(includesAppManagement: true)` or `.withAppManagement` (routine-worker / control / automation).

## Library (engine)

```swift
import MacPermissionKit

let session = PermissionOrchestrator(
    required: PermissionKind.prerequisitesDefaultRequired,
    policy: .standard
)
session.refresh()
let result = await session.advanceStartup()
await session.request(.microphone)
await session.openSettings(.fullDiskAccess)
try session.reset(.screenRecording)
```

Bind the host only to `snapshot`, `pending`, `lastResult`, `relaunchRequired`, `nextRequired`, and `allRequiredSatisfied`.

## Presentation slots

| Slot | Surface |
|---|---|
| `SLOT_PrerequisitesSplash` | `PrerequisitesSplashView` |
| `SLOT_PrerequisitesChecklist` | `PrerequisitesChecklistView` / `PrerequisitesRootView` / `PrerequisitesScene` |
| `SLOT_StartupGlassShell` | `StartupGlassShellView` / `PermissionStartupScene` (legacy) |
| `SLOT_PermissionList` / `SLOT_PermissionRow` | `PermissionListView` / `PermissionRowView` |
| `SLOT_SystemPromptPending` | `SystemPromptPendingView` |
| `SLOT_OpenSettingsCTA` | `OpenSettingsCTAView` |
| `SLOT_DragIntoListHint` | `DragIntoListHintView` |
| `SLOT_QuitAndRelaunch` | `QuitAndRelaunchView` |
| `SLOT_DeniedRecovery` | `DeniedRecoveryView` |
| `SLOT_Completion` | `CompletionView` |

## Command line

Each behavior is its own script:

- `local/matkoson-permissions-help`
- `local/matkoson-permissions-catalog`
- `local/matkoson-permissions-status`
- `local/matkoson-permissions-status-json`
- `local/matkoson-permissions-checklist`
- `local/matkoson-permissions-checklist-json`
- `local/matkoson-permissions-gate`
- `local/matkoson-permissions-gate-json`
- `local/matkoson-permissions-refresh`
- `local/matkoson-permissions-refresh-json`
- `local/matkoson-permissions-request` with a permission id
- `local/matkoson-permissions-open-settings` with a permission id
- `local/matkoson-permissions-reset` with a permission id
- `local/matkoson-permissions-advance`
- `local/build-matkoson-permissions-release`
- `local/sign-matkoson-permissions-developer-id`

## Checks

```text
./local/qa
```

That runs `swift test` and fails when line coverage of `Sources/MacPermissionKit` is below 90%.
