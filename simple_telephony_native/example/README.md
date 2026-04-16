# simple_telephony_native_example

Minimal Flutter app demonstrating every part of `simple_telephony_native`'s
public API on Android:

- **Default-dialer role**: `isDefaultDialerApp()` / `requestDefaultDialerApp()`
- **Live call events**: `initializeForeground(onCallEvent:)` + the
  `SimpleTelephonyNative.instance.events` broadcast stream
- **Device info**: `getDeviceInfo()` — manufacturer, model, Android version
- **SIM enumeration**: `listSimCards()` — per-slot carrier + country ISO
- **Call log**: `listCallLog()` — recent incoming / outgoing / missed calls

## Running

```bash
cd example
flutter pub get
flutter run
```

Runs on a real Android device; SIM + call-log queries return empty on an
emulator without a provisioned SIM. Grant the requested permissions
(phone, call log) when the system prompts, then tap **Request default
dialer role** to exercise the role-management path.

## What this example deliberately does NOT cover

- Placing a call via `placePhoneCall(phoneNumber)` — requires a populated
  phone-number text field, out of scope for the minimal demo.
- The native-side `CallUiLauncher` hook
  (`SimpleTelephonyCallUi.launcher`) for launching a custom
  incoming-call overlay Activity. That integration requires a
  dedicated Activity + a second Flutter engine entry point; see the
  `unify-messages` reference consumer for a full treatment.
- Background call events via `registerBackgroundHandler(...)` — the
  plugin supports them, but this example renders call UI from the
  foreground isolate only.
