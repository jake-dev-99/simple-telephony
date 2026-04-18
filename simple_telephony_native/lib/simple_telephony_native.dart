import 'dart:async';
import 'dart:ui' show CallbackHandle, DartPluginRegistrant, PluginUtilities;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:simple_telephony_platform_interface/simple_telephony_platform_interface.dart';

export 'package:simple_telephony_platform_interface/simple_telephony_platform_interface.dart'
    show
        CallControlResult,
        CallControlStatus,
        CallEventHandler,
        CallLogEntry,
        CallLogFilter,
        CallLogSort,
        CallLogSortField,
        CallType,
        DeviceInfo,
        PhoneCallBase,
        PhoneCallDirection,
        PhoneCallEvent,
        PhoneCallSnapshot,
        PhoneCallState,
        PhoneCallStateX,
        SimCard,
        SortDirection;

/// High-level facade for Android telephony via `InCallService`.
///
/// Provides call control (answer, end, place), event streaming, and
/// background delivery for apps registered as the default dialer.
///
/// Access via [SimpleTelephonyNative.instance].
class SimpleTelephonyNative {
  SimpleTelephonyNative._();

  /// The singleton instance used for all telephony operations.
  static final SimpleTelephonyNative instance = SimpleTelephonyNative._();

  static SimpleTelephonyPlatform get _platform =>
      SimpleTelephonyPlatform.instance;

  static StreamSubscription<void>? _foregroundSubscription;

  /// Broadcast stream of native telephony events in the foreground isolate.
  ///
  /// Events are live-only — if no listener is attached, they are dropped.
  /// Use [getCurrentCalls] to recover state after a restart or listener swap.
  Stream<PhoneCallEvent> get events => _platform.events;

  /// Registers a top-level or static background handler for headless delivery.
  static Future<void> registerBackgroundHandler(
    CallEventHandler handler,
  ) async {
    final CallbackHandle? userHandle =
        PluginUtilities.getCallbackHandle(handler);
    final CallbackHandle? dispatcherHandle =
        PluginUtilities.getCallbackHandle(simpleTelephonyBackgroundDispatcher);

    if (userHandle == null || dispatcherHandle == null) {
      throw ArgumentError(
        'Background handlers must be top-level or static functions.',
      );
    }

    await _platform.registerBackgroundHandler(
      dispatcherHandle: dispatcherHandle.toRawHandle(),
      userHandle: userHandle.toRawHandle(),
    );
  }

  /// Attaches a foreground listener for call events.
  static Future<void> initializeForeground({
    required CallEventHandler onCallEvent,
  }) async {
    await disposeForegroundListener();
    _foregroundSubscription = SimpleTelephonyNative.instance.events.listen(
      (PhoneCallEvent event) async {
        try {
          await onCallEvent(event);
        } catch (error, stackTrace) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stackTrace,
              library: 'simple_telephony_native',
              context: ErrorDescription(
                'while handling a foreground phone call event',
              ),
            ),
          );
        }
      },
    );
  }

  /// Removes the active foreground listener, if one is registered.
  static Future<void> disposeForegroundListener() async {
    await _foregroundSubscription?.cancel();
    _foregroundSubscription = null;
  }

  /// Returns the current native call snapshots from persisted state.
  Future<List<PhoneCallSnapshot>> getCurrentCalls() =>
      _platform.getCurrentCalls();

  /// Places an outbound phone call using [phoneNumber].
  Future<CallControlResult> placePhoneCall(String phoneNumber) =>
      _platform.placePhoneCall(phoneNumber);

  /// Attempts to answer the call represented by [callId].
  Future<CallControlResult> answerPhoneCall(String callId) =>
      _platform.answerPhoneCall(callId);

  /// Attempts to hang up the call represented by [callId].
  Future<CallControlResult> endPhoneCall(String callId) =>
      _platform.endPhoneCall(callId);

  // Default-dialer role observation + request lives in
  // `simple_permissions_native`:
  //
  // ```dart
  // import 'package:simple_permissions_native/simple_permissions_native.dart';
  //
  // final held = await SimplePermissionsNative.instance
  //     .check(const DefaultDialerApp());
  // final granted = await SimplePermissionsNative.instance
  //     .request(const DefaultDialerApp());
  //
  // // Reactive observation — refreshes on resume and after each request.
  // final observer = SimplePermissionsNative.instance
  //     .observe(const [DefaultDialerApp()]);
  // ```
  //
  // Removed from this facade in v0.4.0 so access-state vocabulary
  // (runtime permissions + app-role handlers) lives in exactly one
  // plugin.

  /// Lists call-log (history) entries matching the given typed filter.
  ///
  /// Requires `READ_CALL_LOG` permission (request via
  /// `simple_permissions_native`).
  Future<List<CallLogEntry>> listCallLog({
    CallLogFilter? filter,
    CallLogSort? sort,
    int? limit,
    int? offset,
  }) =>
      _platform.listCallLog(
        filter: filter,
        sort: sort,
        limit: limit,
        offset: offset,
      );

  /// Returns basic device info (build, Android version, SIM slot count).
  Future<DeviceInfo> getDeviceInfo() => _platform.getDeviceInfo();

  /// Enumerates active SIM subscriptions on the device. Requires
  /// `READ_PHONE_STATE`.
  Future<List<SimCard>> listSimCards() => _platform.listSimCards();
}

/// Entrypoint used by Android to bootstrap a headless isolate for call events.
@pragma('vm:entry-point')
Future<void> simpleTelephonyBackgroundDispatcher() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  final MethodChannelSimpleTelephony platform =
      SimpleTelephonyPlatform.instance as MethodChannelSimpleTelephony;

  final int? rawHandlerHandle =
      await platform.actionsChannel.invokeMethod<int>(
    'getBackgroundHandlerHandle',
  );
  final CallbackHandle? callbackHandle = rawHandlerHandle == null
      ? null
      : CallbackHandle.fromRawHandle(rawHandlerHandle);
  final Function? callback = callbackHandle == null
      ? null
      : PluginUtilities.getCallbackFromHandle(callbackHandle);

  if (callback != null && callback is! CallEventHandler) {
    throw StateError(
      'Registered background handler has the wrong signature: '
      '${callback.runtimeType}',
    );
  }

  final CallEventHandler? typedCallback = callback as CallEventHandler?;

  platform.backgroundEventsChannel
      .setMethodCallHandler((MethodCall call) async {
    if (call.method != 'deliverBackgroundEvent') {
      return;
    }

    if (typedCallback == null) {
      return;
    }

    final Map<String, dynamic> rawEvent =
        Map<String, dynamic>.from(call.arguments as Map);
    final PhoneCallEvent event = PhoneCallEvent.fromRaw(rawEvent);

    try {
      await typedCallback(event);
    } catch (error, stackTrace) {
      // Don't let a handler error kill the background isolate — report it
      // and continue so subsequent events can still be delivered.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'simple_telephony_native',
          context: ErrorDescription(
            'while handling a background phone call event',
          ),
        ),
      );
    }

    // Always acknowledge, even after handler errors. The event was delivered;
    // letting it expire and redeliver won't fix the handler bug and will
    // cause an infinite retry loop.
    if (event.eventId != null && event.eventId!.isNotEmpty) {
      await platform.actionsChannel.invokeMethod<void>(
        'ackBackgroundEvent',
        event.eventId,
      );
    }
  });

  await platform.actionsChannel
      .invokeMethod<void>('backgroundDispatcherReady');
}
