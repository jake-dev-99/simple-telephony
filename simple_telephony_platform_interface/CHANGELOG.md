## 1.0.0

- fix(UNFY-345): commit stable Flutter analyzer migration
- chore(release): reset versions to align with pub.dev (smallest iteration)
- fix: address Copilot + Sourcery review on PR #23
- docs: genericize simple-permissions references in READMEs + comments
- docs(platform_interface): make UnimplementedError messages actionable
- refactor(platform_interface): make events stream `late final` instead of lazy getter with side effect
- refactor(dart): harden channel decoding and lift background ack to platform interface
- ci: address review feedback + unblock CI
- feat: delegate DeviceInfoHandler permission check to PermissionGuards
- breaking: delegate dialer-role to simple_permissions_native
- chore(pubspec): add repository, issue_tracker + topics across federation
- feat(android): native CallUiLauncher seam for host-owned incoming-call UI (0.3.0)
- refactor(android): rename Kotlin package simple_telecom -> simple_telephony
- feat(telephony): call log, device info, SIM cards; fix facade class names
- Additional Enhancements
- Implemented Federation
- Implemented Federation

## 0.1.1

### Reset to align with pub.dev's published series

This package on pub.dev is at 0.1.0. Local git tag 0.5.0 (and
develop pubspec at 0.5.0) was authored ahead of the next publish
but never reached pub.dev. Orphan tag deleted from origin and the
version reset to the smallest patch above the last-published
version (0.1.0 → 0.1.1).

Cross-package constraints lowered to match the published series:
* `simple_telephony_*` siblings: `^0.5.0` → `^0.1.0`
* `simple_query`: `^0.6.0` → `^0.2.0`

The 0.2 — 0.5 work described in the entries below is not lost —
it lives in source and will surface in published form through
subsequent patch / minor / major bumps as appropriate. Entries
kept for archival reference.

## 0.5.0

### Added (additive — non-breaking)
- `fetchBackgroundHandlerHandle()` — resolves the Dart callback
  handle for the registered background message handler so the native
  side can spin up an isolate without round-tripping through the
  foreground engine.
- `setBackgroundMessageHandler(handle)` — registers the Dart
  callback that processes background-delivered call events.
- `acknowledgeBackgroundEvent(eventId)` — releases a
  `CallStore`-queued event after the Dart side has persisted it,
  so a redelivery on cold-start doesn't double-fire.
- `notifyBackgroundDispatcherReady()` — signals from the background
  isolate that it's ready to receive events; native side starts
  draining the queue once this resolves.
- `listCallLog()`, `getDeviceInfo()`, `listSimCards()` — typed
  call-log + device + SIM enumeration. Default implementations
  throw `UnimplementedError` ("Android-only and not implemented on
  the current platform").

### Changed
- Default `UnimplementedError` messages reworded to indicate
  Android-only scope rather than telling consumers to add the
  implementation package to pubspec (which is misleading in a
  federated plugin where `default_package` resolution handles it).
- `simple_telephony_android` now delegates its internal
  `READ_PHONE_STATE` check to `simple_permissions_android`'s
  `PermissionGuards` so the plugin family has a single source of
  truth for access-state observations.

## 0.4.0

### Breaking
- Removed `SimpleTelephonyPlatform.isDefaultDialerApp()` and `requestDefaultDialerApp()`. Dialer role is now owned by `simple_permissions_native` via the generic `DefaultDialerApp` permission.

## 0.3.0

- Federation version bump. No public API change. The
  `simple_telephony_android` implementation gains a native-only
  `CallUiLauncher` seam (Kotlin interface + registry object), which
  does not cross the platform interface.

## 0.2.1

- Federation version bump for the Kotlin package rename in
  `simple_telephony_android`. No public API change.

## 0.2.0

- NEW: `CallLogEntry` plus `CallLogFilter` and `CallLogSort` query
  types; `PlatformInterface.listCallLog(...)` contract.
- NEW: `DeviceInfo` model; `PlatformInterface.getDeviceInfo()`.
- NEW: `SimCard` model; `PlatformInterface.listSimCards()`.
- All existing `PhoneCall*` types (event, snapshot, base, state) and
  `CallControlResult` / `CallControlStatus` remain unchanged from 0.1.

## 0.1.0

- Initial release
- Android-only: InCallService integration for default dialer apps
- Foreground event streaming via EventChannel
- Background event delivery with at-least-once guarantees via headless FlutterEngine
- Call control: answer, end, and place phone calls
- Typed `CallControlResult` with granular status codes
- Persistent call state via `getCurrentCalls()` for app restart recovery
- Default dialer role management