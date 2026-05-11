import 'dart:async';
import 'dart:ui' show CallbackHandle, DartPluginRegistrant, PluginUtilities;

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
      (PhoneCallEvent event) => _invokeSafely(
        onCallEvent,
        event,
        context: 'while handling a foreground phone call event',
      ),
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

  // Default-dialer role observation + request is out of scope for this
  // plugin — host apps handle it with whatever permissions helper they
  // choose (`permission_handler`, `simple_permissions_native`, or a
  // hand-rolled `RoleManager` method channel). Removed from this facade
  // in v0.4.0.

  /// Lists call-log (history) entries matching the given typed filter.
  ///
  /// Requires `READ_CALL_LOG` permission; request it with whatever
  /// permissions helper the host app uses.
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

/// Invokes [handler] with [event], reporting any error via [FlutterError] so a
/// single faulty handler invocation does not kill the listener / isolate.
Future<void> _invokeSafely(
  CallEventHandler handler,
  PhoneCallEvent event, {
  required String context,
}) async {
  try {
    await handler(event);
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'simple_telephony_native',
        context: ErrorDescription(context),
      ),
    );
  }
}

/// Resolves the registered user callback from its raw handle, or returns
/// `null` if none is registered. Throws [StateError] if the registered
/// callback has the wrong signature.
CallEventHandler? _resolveBackgroundHandler(int? rawHandle) {
  if (rawHandle == null) return null;
  final CallbackHandle handle = CallbackHandle.fromRawHandle(rawHandle);
  final Function? callback = PluginUtilities.getCallbackFromHandle(handle);
  if (callback == null) return null;
  if (callback is CallEventHandler) return callback;
  throw StateError(
    'Registered background handler has the wrong signature: '
    '${callback.runtimeType}',
  );
}

/// Entrypoint used by Android to bootstrap a headless isolate for call events.
@pragma('vm:entry-point')
Future<void> simpleTelephonyBackgroundDispatcher() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  final SimpleTelephonyPlatform platform = SimpleTelephonyPlatform.instance;
  final CallEventHandler? handler =
      _resolveBackgroundHandler(await platform.fetchBackgroundHandlerHandle());

  platform.setBackgroundMessageHandler((PhoneCallEvent event) async {
    if (handler != null) {
      await _invokeSafely(
        handler,
        event,
        context: 'while handling a background phone call event',
      );
    }

    // Always acknowledge, even after handler errors or when no handler is
    // registered. The event was delivered; letting it expire and redeliver
    // won't fix a handler bug and would cause an infinite retry loop.
    final String? eventId = event.eventId;
    if (eventId != null && eventId.isNotEmpty) {
      await platform.acknowledgeBackgroundEvent(eventId);
    }
  });

  await platform.notifyBackgroundDispatcherReady();
}
