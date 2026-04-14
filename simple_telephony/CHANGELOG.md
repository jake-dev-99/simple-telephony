## 0.1.0

- Initial release
- Android-only: InCallService integration for default dialer apps
- Foreground event streaming via EventChannel
- Background event delivery with at-least-once guarantees via headless FlutterEngine
- Call control: answer, end, and place phone calls
- Typed `CallControlResult` with granular status codes
- Persistent call state via `getCurrentCalls()` for app restart recovery
- Default dialer role management
