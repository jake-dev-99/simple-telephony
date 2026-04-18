## 0.5.0

### Changed
- `DeviceInfoHandler.hasPhoneStatePermission()` now delegates to `PermissionGuards.isPermissionGranted(..., READ_PHONE_STATE)` from `simple_permissions_android` instead of calling `ContextCompat.checkSelfPermission(...)` directly.
- `android/build.gradle` adds `implementation project(':simple_permissions_android')`. Resolves via Flutter's plugin-loader because `simple_permissions_native` is a declared runtime dep of the native facade.

## 0.4.0

### Breaking
- `CallManager` no longer exposes `isDefaultDialerApp()` / `requestDefaultDialerApp()`; `TelecomMethodHandler` no longer handles the `isDefaultDialerApp` / `requestDefaultDialerApp` method-channel calls. Dialer-role observation + request moved to `simple_permissions_native` via the generic `DefaultDialerApp` permission.

### Internal
- Dropped `RoleManager` field + `android.app.role.RoleManager` imports from `CallManager`. Dropped the pending-request queue + activity-result listener plumbing that only served role requests.

## 0.3.0

- NEW: `CallUiLauncher` interface + `SimpleTelephonyCallUi.launcher`
  registry. Host apps register a launcher (typically in
  `Application.onCreate`) to receive every call state event on the
  InCallService binder thread. Intended use is launching an
  incoming-call Activity that hosts its own Flutter engine without
  routing the launch decision through Dart (which would add cold-start
  latency when the app process is dead). The hook is purely additive
  and opt-in — plugin consumers that only need Dart-level events do
  not need to register a launcher. See `CallUiLauncher` KDoc for the
  payload schema and threading contract.

## 0.2.1

- REFACTOR: renamed internal Kotlin package from
  `io.simplezen.simple_telecom` to `io.simplezen.simple_telephony` for
  consistency with the federated plugin name. No Dart API change. Host
  apps that reference the plugin's InCallService by fully-qualified
  name in their merged Android manifest (for instance, overriding it
  via `<service tools:node="remove">`) must update the class name to
  `io.simplezen.simple_telephony.SimpleTelephonyInCallService`.

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
