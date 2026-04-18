## 0.5.0

### Changed
- `simple_permissions_native: ^1.4.0` now a declared runtime dep (previously referenced only in doc comments after the v0.4.0 role removal). Makes Flutter's plugin-loader wire `:simple_permissions_android` into the consuming app's Gradle build, which lets `simple_telephony_android` delegate its inline `READ_PHONE_STATE` check to `PermissionGuards`.

### Internal
- `DeviceInfoHandler.hasPhoneStatePermission()` uses `PermissionGuards.isPermissionGranted(...)` instead of `ContextCompat.checkSelfPermission(...)`. Rule 2 of the cross-plugin access-state consolidation (*"native reads flow through simple-permissions"*) now upheld end-to-end in this plugin.

## 0.4.0

### Breaking
- Removed `SimpleTelephonyNative.instance.isDefaultDialerApp()` and `requestDefaultDialerApp()`. Dialer-role observation + request lives in `simple_permissions_native` now — call `SimplePermissionsNative.instance.check(DefaultDialerApp())` / `request(DefaultDialerApp())`, or `observe([DefaultDialerApp()])` for reactive updates. This makes `simple_permissions_native` the single source of truth for access-state vocabulary (runtime permissions + app-role handlers) across the plugin family.

### Internal
- `CallManager` + `TelecomMethodHandler` drop the `RoleManager` plumbing (method-channel handlers, activity-result listener, pending-request queue). Native surface shrinks to actual telephony operations.

## 0.3.0

- `simple_telephony_android` now exposes a native-side `CallUiLauncher`
  interface that default-dialer host apps can register via
  `SimpleTelephonyCallUi.launcher` to receive call events on the
  InCallService binder thread. Enables launching a custom
  incoming-call Activity without routing the launch decision through
  Dart (which would add cold-start latency in the app-killed case).
  Pure-Dart consumers are unaffected — the hook is opt-in. See the
  `simple_telephony_android` 0.3.0 CHANGELOG entry for details.

## 0.2.1

- Transitive bump for the Kotlin package rename in
  `simple_telephony_android` (`io.simplezen.simple_telecom` →
  `io.simplezen.simple_telephony`). No Dart API change.

## 0.2.0

- NEW: `listCallLog(filter, sort)` returning typed `CallLogEntry`
  records.
- NEW: `getDeviceInfo()` returning model, manufacturer, and Android
  version.
- NEW: `listSimCards()` enumerating active SIM cards.
- RENAME: facade class exposed to Dart is `SimpleTelephonyNative`
  (previously `SimpleTelecom`), matching the federated package name.

## 0.1.0

- Initial release
- Android-only: InCallService integration for default dialer apps
- Foreground event streaming via EventChannel
- Background event delivery with at-least-once guarantees via headless FlutterEngine
- Call control: answer, end, and place phone calls
- Typed `CallControlResult` with granular status codes
- Persistent call state via `getCurrentCalls()` for app restart recovery
- Default dialer role management
