## 0.2.0

### Added
- New models in `simple_telephony_platform_interface`: `CallLogEntry` + `CallType` enum, `DeviceInfo`, `SimCard`, `CallLogFilter` / `CallLogSort`, `SortDirection`. `SimCard` + `DeviceInfo` are relocated from `simple_sms_native` — telephony is the correct domain owner.
- `SimpleTelephonyNative.instance.listCallLog({filter, sort, limit, offset})` — typed call-log listing backed by `simple_query` against `QueryDomain.calls`. `CallLogFilter` supports `types`, `dateFrom`/`dateTo`, `numberContains`, `subscriptionId`, `isNew`.
- `SimpleTelephonyNative.instance.getDeviceInfo()` — `Build` metadata + SIM slot count. NOT a content-provider query; routed through a new `io.simplezen.simple_telephony/device_info` MethodChannel handled by the Kotlin `DeviceInfoHandler`.
- `SimpleTelephonyNative.instance.listSimCards()` — active subscription enumeration via `SubscriptionManager`. Same MethodChannel as above.

### Fixed
- Dart facade previously referenced nonexistent `SimpleTelephonyNativePlatform` / `MethodChannelSimpleTelephonyNative` symbols (stalled rename). Corrected to the platform-interface's real class names.

### Internal
- `simple_telephony_android` picks up `simple_query: ^0.2.0` as a dep for the call-log implementation.

## 0.1.0

- Initial release
- Android-only: InCallService integration for default dialer apps
- Foreground event streaming via EventChannel
- Background event delivery with at-least-once guarantees via headless FlutterEngine
- Call control: answer, end, and place phone calls
- Typed `CallControlResult` with granular status codes
- Persistent call state via `getCurrentCalls()` for app restart recovery
- Default dialer role management
