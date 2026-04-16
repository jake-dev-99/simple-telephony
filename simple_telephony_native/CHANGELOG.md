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
