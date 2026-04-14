import 'dart:async';
import 'dart:ui' show CallbackHandle, DartPluginRegistrant, PluginUtilities;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'src/call_control_result.dart';
import 'src/phone_call_event.dart';
import 'src/phone_call_snapshot.dart';

export 'src/call_control_result.dart';
export 'src/phone_call_base.dart';
export 'src/phone_call_event.dart';
export 'src/phone_call_snapshot.dart';

/// Callback signature for receiving phone call events.
///
/// Used by both [SimpleTelephony.initializeForeground] and
/// [SimpleTelephony.registerBackgroundHandler].
typedef CallEventHandler = Future<void> Function(PhoneCallEvent event);

/// High-level facade for Android telephony via `InCallService`.
///
/// Provides call control (answer, end, place), event streaming, and
/// background delivery for apps registered as the default dialer.
///
/// Access via [SimpleTelephony.instance].
class SimpleTelephony {
  SimpleTelephony._();

  /// The singleton instance used for all telephony operations.
  static final SimpleTelephony instance = SimpleTelephony._();

  static const MethodChannel _actionsChannel =
      MethodChannel('io.simplezen.simple_telephony/telecom_actions');
  static const EventChannel _foregroundEventsChannel =
      EventChannel('io.simplezen.simple_telephony/foreground_events');
  static const MethodChannel _backgroundEventsChannel =
      MethodChannel('io.simplezen.simple_telephony/background_events');

  static Stream<PhoneCallEvent>? _events;
  static StreamSubscription<void>? _foregroundSubscription;

  /// Broadcast stream of native telephony events in the foreground isolate.
  ///
  /// Events are live-only — if no listener is attached, they are dropped.
  /// Use [getCurrentCalls] to recover state after a restart or listener swap.
  Stream<PhoneCallEvent> get events => _events ??= _foregroundEventsChannel
          .receiveBroadcastStream()
          .map((dynamic event) {
        return PhoneCallEvent.fromRaw(Map<String, dynamic>.from(event as Map));
      }).asBroadcastStream();

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

    await _actionsChannel.invokeMethod<void>('registerBackgroundHandler', {
      'dispatcherHandle': dispatcherHandle.toRawHandle(),
      'handlerHandle': userHandle.toRawHandle(),
    });
  }

  /// Attaches a foreground listener for call events.
  static Future<void> initializeForeground({
    required CallEventHandler onCallEvent,
  }) async {
    await disposeForegroundListener();
    _foregroundSubscription = SimpleTelephony.instance.events.listen(
      (PhoneCallEvent event) async {
        try {
          await onCallEvent(event);
        } catch (error, stackTrace) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stackTrace,
              library: 'simple_telephony',
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
    // Reset the cached stream so a fresh EventChannel subscription is created
    // next time. This recovers from a dead stream after engine detach.
    _events = null;
  }

  /// Returns the current native call snapshots from persisted state.
  Future<List<PhoneCallSnapshot>> getCurrentCalls() async {
    final List<dynamic> rawCalls =
        await _actionsChannel.invokeMethod<List<dynamic>>('getCurrentCalls') ??
            const <dynamic>[];

    return rawCalls
        .map(
          (dynamic raw) => PhoneCallSnapshot.fromRaw(
            Map<String, dynamic>.from(raw as Map),
          ),
        )
        .toList(growable: false);
  }

  /// Places an outbound phone call using [phoneNumber].
  Future<CallControlResult> placePhoneCall(String phoneNumber) async =>
      _invokeControl('placePhoneCall', phoneNumber);

  /// Attempts to answer the call represented by [callId].
  Future<CallControlResult> answerPhoneCall(String callId) async =>
      _invokeControl('answerPhoneCall', callId);

  /// Attempts to hang up the call represented by [callId].
  Future<CallControlResult> endPhoneCall(String callId) async =>
      _invokeControl('endPhoneCall', callId);

  /// Returns whether this app currently holds the default dialer role.
  Future<bool> isDefaultDialerApp() async =>
      (await _actionsChannel.invokeMethod<bool>('isDefaultDialerApp')) == true;

  /// Requests the default dialer role. Returns true if granted.
  Future<bool> requestDefaultDialerApp() async =>
      (await _actionsChannel.invokeMethod<bool>('requestDefaultDialerApp')) ==
      true;

  Future<CallControlResult> _invokeControl(
    String method, [
    Object? argument,
  ]) async {
    final dynamic raw = await _actionsChannel.invokeMethod(method, argument);
    return CallControlResult.fromRaw(Map<String, dynamic>.from(raw as Map));
  }
}

/// Entrypoint used by Android to bootstrap a headless isolate for call events.
@pragma('vm:entry-point')
Future<void> simpleTelephonyBackgroundDispatcher() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  final int? rawHandlerHandle =
      await SimpleTelephony._actionsChannel.invokeMethod<int>(
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

  final CallEventHandler? typedCallback =
      callback as CallEventHandler?;

  SimpleTelephony._backgroundEventsChannel
      .setMethodCallHandler((MethodCall call) async {
    if (call.method != 'deliverBackgroundEvent') {
      return;
    }

    if (typedCallback == null) {
      return;
    }

    final Map<String, dynamic> rawEvent =
        Map<String, dynamic>.from(call.arguments as Map);
    final event = PhoneCallEvent.fromRaw(rawEvent);

    try {
      await typedCallback(event);
    } catch (error, stackTrace) {
      // Don't let a handler error kill the background isolate — report it
      // and continue so subsequent events can still be delivered.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'simple_telephony',
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
      await SimpleTelephony._actionsChannel.invokeMethod<void>(
        'ackBackgroundEvent',
        event.eventId,
      );
    }
  });

  await SimpleTelephony._actionsChannel
      .invokeMethod<void>('backgroundDispatcherReady');
}
