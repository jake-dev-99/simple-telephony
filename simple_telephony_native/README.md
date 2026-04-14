# simple_telephony_native_native

Android-only Flutter plugin for phone call management via `InCallService`.

When your app is registered as the **default dialer**, Android routes all
incoming and outgoing call lifecycle events through this plugin — even when
the Flutter engine is not yet running.

## How it works

```
Android OS (TelecomManager / InCallService)
        │
        ▼
TelecomServiceRuntime          ← native singleton, source of truth
├── CallStore (SharedPrefs)    ← persists call records + event queue
├── ForegroundChannelBridge    ← EventChannel → Dart UI (live-only, drops if no listener)
└── BackgroundFlutterBridge    ← headless FlutterEngine → Dart callback (at-least-once)
        │
        ▼
SimpleTelephonyNative                ← Dart facade your app talks to
```

**Key design decisions:**

- **Native is the source of truth.** Call state is captured and persisted on
  the Android side before Flutter is involved. The Dart layer is an observer.
- **Two delivery paths.** Foreground events stream in real-time but are
  dropped if nobody is listening. Background events are queued in
  SharedPreferences and delivered with at-least-once guarantees via a
  separate headless FlutterEngine.
- **Recovery via `getCurrentCalls()`.** After an app restart or listener
  replacement, read the current snapshot and re-subscribe. The foreground
  stream does not replay history.

## Setup

### 1. Become the default dialer

```dart
final granted = await SimpleTelephonyNative.instance.requestDefaultDialerApp();
```

The system will show a role-request dialog. Until your app holds the default
dialer role, `InCallService` callbacks will not fire and call control methods
will return `permissionDenied`.

### 2. Register a background handler

```dart
@pragma('vm:entry-point')
Future<void> onBackgroundCallEvent(PhoneCallEvent event) async {
  // Runs in a headless isolate — no UI access.
  // Persist the event, send a notification, etc.
}

await SimpleTelephonyNative.registerBackgroundHandler(onBackgroundCallEvent);
```

The handler **must** be a top-level or static function (it is looked up by
callback handle across isolates). Register it once during app startup.

### 3. Listen for foreground events

```dart
await SimpleTelephonyNative.initializeForeground(
  onCallEvent: (PhoneCallEvent event) async {
    // Update your UI.
  },
);
```

Only one foreground listener is active at a time. Calling
`initializeForeground` again replaces the previous listener.

### 4. Recover state after restart

```dart
final calls = await SimpleTelephonyNative.instance.getCurrentCalls();
// calls is List<PhoneCallSnapshot> — the persisted state of all active calls.
```

### 5. Control calls

```dart
final answer = await SimpleTelephonyNative.instance.answerPhoneCall(callId);
final end    = await SimpleTelephonyNative.instance.endPhoneCall(callId);
final place  = await SimpleTelephonyNative.instance.placePhoneCall('+15551234567');

if (!answer.isSuccess) {
  print('${answer.status}: ${answer.message}');
}
```

`answerPhoneCall` and `endPhoneCall` require a **live** Android `Call` object
to be attached. If the call has already disconnected or the process restarted,
the status will be `notAttached` or `notFound`.

`placePhoneCall` returns `requested` (not `success`) because
`TelecomManager.placeCall()` is fire-and-forget — the actual outcome arrives
asynchronously via `onCallAdded`.

### 6. Clean up

```dart
await SimpleTelephonyNative.disposeForegroundListener();
```

## Status codes

| `CallControlStatus` | Meaning |
|---|---|
| `success` | Operation completed |
| `requested` | Request sent to the system (used by `placePhoneCall`) |
| `notFound` | No record of this `callId` |
| `notAttached` | Record exists but the live OS call object is gone |
| `permissionDenied` | Missing default dialer role or `CALL_PHONE` permission |
| `platformFailure` | Unexpected native error |
| `invalidArguments` | Bad input (null/blank phone number or callId) |

## Call states

Events and snapshots carry a `state` string that maps to `PhoneCallState`:

`newCall` → `ringing` → `active` → `disconnecting` → `disconnected` (incoming)
`newCall` → `dialing` → `connecting` → `active` → `disconnecting` → `disconnected` (outgoing)

## Host app requirements

Your `AndroidManifest.xml` must declare:

```xml
<uses-permission android:name="android.permission.CALL_PHONE" />
```

The plugin's own manifest already declares `BIND_INCALL_SERVICE` and
registers the `InCallService` — these merge automatically.

**Min SDK:** 30 (Android 11). The `InCallService` + `RoleManager` APIs
require this minimum.

## Limitations

- **Android only.** iOS CallKit handles VoIP calls, not cellular — a
  fundamentally different use case. macOS/Linux/Windows have no telephony APIs.
- **Default dialer is exclusive.** Only one app can be the default dialer.
  When your app takes the role, the previous dialer loses it.
- **No hold/merge/swap.** Only answer, end, and place are implemented.
- **At-least-once, not exactly-once.** Background events may be delivered
  more than once if the handler is slow (>30 s) or the process crashes
  mid-delivery. Design your handler to be idempotent.
