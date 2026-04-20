## 0.5.0

- Federation version bump. No public API change. The
  `simple_telephony_android` implementation now delegates its internal
  `READ_PHONE_STATE` check to `simple_permissions_android`'s
  `PermissionGuards` so the plugin family has a single source of truth
  for access-state observations.

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
