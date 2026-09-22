# MacPermissionKit

Logic-only Swift 6 permission engine for a later macOS 26 host. This package owns one process TCC session: the catalog, probes, request and Settings strategies, an observable orchestrator, and slot contracts. It does not ship SwiftUI views.

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

`advanceStartup()` asks for one ungranted required permission and returns. Screen Recording and Input Monitoring set `relaunchRequired` after a grant. Settings-only permissions (Full Disk Access, App Management, folders, USB, system audio) never report `.granted` from `request`; a later `refresh()` may observe Full Disk Access by reading a protected preferences file.

Screen Recording uses `CGPreflightScreenCaptureAccess` and `CGRequestScreenCaptureAccess`. The package does not call the screen-sharing picker to probe.

Local Network status stays `.unknown`. The request sends one UDP packet to the mDNS group so the system can show its prompt.

`reset` runs the system TCC reset tool for permissions with a stable service name. System audio, local network, notifications, USB, and App Management do not, because guessing a service name could reset the wrong row.

## Slots

`PermissionSlot` names the host-owned presentation points (`SLOT_StartupGlassShell` through `SLOT_Completion`). `PermissionPresentationPolicy.standard` treats camera, system audio, automation, and local network as optional. `PermissionSlotCopy` supplies the button titles and the drag-into-list sentence.

## Command line

```text
matkoson-permissions help
matkoson-permissions catalog
matkoson-permissions status [--json]
matkoson-permissions request <id>
matkoson-permissions open-settings <id>
matkoson-permissions reset <id>
matkoson-permissions advance
```

`status` and `catalog` do not present dialogs. `request`, `open-settings`, `reset`, and `advance` perform the same actions as the library.

## Checks

```text
./local/qa
```

That runs `swift test` and fails when line coverage of `Sources/MacPermissionKit` is below 90%.
