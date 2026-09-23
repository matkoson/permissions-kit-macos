# MacPermissionKit

Swift 6 permission engine for macOS 26+ with a Liquid Glass SwiftUI + SwiftUIX presentation layer.

Requires Swift 6.2+ and macOS 26+.

## Library

```swift
import MacPermissionKit

let session = PermissionOrchestrator(
    required: PermissionKind.startupDefaultOrder
)
session.refresh()
let result = await session.advanceStartup()
await session.request(.microphone)
await session.openSettings(.fullDiskAccess)
try session.reset(.screenRecording)
```

Bind the host only to `snapshot`, `pending`, `lastResult`, `relaunchRequired`, `nextRequired`, and `allRequiredSatisfied`.

## Presentation

```swift
import MacPermissionKit
import SwiftUI

@main
struct HostApp: App {
    @State private var session = PermissionSessionController()

    var body: some Scene {
        PermissionStartupScene(session: session)

        Window("Settings", id: "settings") {
            PermissionSettingsPane(session: session)
        }
    }
}
```

| Slot | Surface |
|---|---|
| `SLOT_StartupGlassShell` | `StartupGlassShellView` / `PermissionStartupScene` |
| `SLOT_PermissionList` / `SLOT_PermissionRow` | `PermissionListView` / `PermissionRowView` |
| `SLOT_SystemPromptPending` | `SystemPromptPendingView` |
| `SLOT_OpenSettingsCTA` | `OpenSettingsCTAView` |
| `SLOT_DragIntoListHint` | `DragIntoListHintView` |
| `SLOT_QuitAndRelaunch` | `QuitAndRelaunchView` |
| `SLOT_DeniedRecovery` | `DeniedRecoveryView` |
| `SLOT_Completion` | `CompletionView` |

`PermissionSessionController` implements `PermissionStartupGlassShellSlot` and owns the orchestrator. Chrome uses SwiftUI Liquid Glass (`glassEffect`, `GlassEffectContainer`, `.glass` / `.glassProminent`) plus SwiftUIX `WindowReader` for keeping the host window frontmost during TCC prompts.

`PermissionPresentationPolicy.standard` treats camera, system audio, automation, and local network as optional. `PermissionSlotCopy` supplies button titles and the drag-into-list sentence.

## Command line

Each behavior is its own script:

- `local/matkoson-permissions-help`
- `local/matkoson-permissions-catalog`
- `local/matkoson-permissions-status`
- `local/matkoson-permissions-status-json`
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
