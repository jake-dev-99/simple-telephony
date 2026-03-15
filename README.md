# simple-telephony

Android-only Flutter plugin for default-dialer and `InCallService` integration.

## What changed

This package now treats Android as the durable source of truth for live calls:

- call state is persisted natively
- foreground Flutter receives events through an `EventChannel`
- background Flutter receives events through a headless engine bootstrap
- answering or ending a call returns a typed control result instead of a bare `bool`

## Host app requirements

The host app must:

1. Become the default dialer before expecting call control or `InCallService` callbacks.
2. Register a top-level background handler during app startup.
3. Initialize the foreground listener when the UI isolate is running.

Example:

```dart
import 'package:simple_telephony/simple_telephony.dart';

@pragma('vm:entry-point')
Future<void> handleBackgroundCall(PhoneCallEvent event) async {
  // Persist, notify, or route the event into app-specific behavior.
}

Future<void> bootstrapTelephony() async {
  await SimpleTelecom.registerBackgroundHandler(handleBackgroundCall);
  await SimpleTelecom.initializeForeground(
    onCallEvent: (PhoneCallEvent event) async {
      // Update UI state.
    },
  );
}
```

Foreground state recovery:

```dart
final calls = await SimpleTelecom.instance.getCurrentCalls();
final events = SimpleTelecom.instance.events;
```

Control methods:

```dart
final result = await SimpleTelecom.instance.answerPhoneCall(callId);
if (!result.isSuccess) {
  // Inspect result.status / result.message.
}
```
