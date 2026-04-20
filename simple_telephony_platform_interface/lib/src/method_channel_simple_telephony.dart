import 'package:flutter/services.dart';

import 'call_control_result.dart';
import 'phone_call_event.dart';
import 'phone_call_snapshot.dart';
import 'platform_interface.dart';

/// Channel names shared between Dart and the native platform.
const String actionsChannelName =
    'io.simplezen.simple_telephony/telecom_actions';
const String foregroundEventsChannelName =
    'io.simplezen.simple_telephony/foreground_events';
const String backgroundEventsChannelName =
    'io.simplezen.simple_telephony/background_events';

/// Default [SimpleTelephonyPlatform] implementation using Flutter
/// platform channels.
class MethodChannelSimpleTelephony extends SimpleTelephonyPlatform {
  /// The method channel for call control and registration.
  final MethodChannel actionsChannel = const MethodChannel(actionsChannelName);

  /// The event channel for foreground call events.
  final EventChannel foregroundEventsChannel =
      const EventChannel(foregroundEventsChannelName);

  /// The method channel for background event delivery.
  final MethodChannel backgroundEventsChannel =
      const MethodChannel(backgroundEventsChannelName);

  late final Stream<PhoneCallEvent> _events = foregroundEventsChannel
      .receiveBroadcastStream()
      .map((dynamic event) => PhoneCallEvent.fromRaw(_asStringMap(event)))
      .asBroadcastStream();

  @override
  Stream<PhoneCallEvent> get events => _events;

  @override
  Future<List<PhoneCallSnapshot>> getCurrentCalls() async {
    final Object? raw = await actionsChannel.invokeMethod('getCurrentCalls');
    if (raw == null) return const <PhoneCallSnapshot>[];
    final List<Object?> rawCalls = _asList(raw);
    return rawCalls
        .map((Object? entry) => PhoneCallSnapshot.fromRaw(_asStringMap(entry)))
        .toList(growable: false);
  }

  @override
  Future<CallControlResult> placePhoneCall(String phoneNumber) =>
      _invokeControl('placePhoneCall', phoneNumber);

  @override
  Future<CallControlResult> answerPhoneCall(String callId) =>
      _invokeControl('answerPhoneCall', callId);

  @override
  Future<CallControlResult> endPhoneCall(String callId) =>
      _invokeControl('endPhoneCall', callId);

  @override
  Future<void> registerBackgroundHandler({
    required int dispatcherHandle,
    required int userHandle,
  }) async {
    await actionsChannel.invokeMethod<void>('registerBackgroundHandler', {
      'dispatcherHandle': dispatcherHandle,
      'handlerHandle': userHandle,
    });
  }

  @override
  Future<int?> fetchBackgroundHandlerHandle() =>
      actionsChannel.invokeMethod<int>('getBackgroundHandlerHandle');

  @override
  void setBackgroundMessageHandler(
    Future<void> Function(PhoneCallEvent event) onEvent,
  ) {
    backgroundEventsChannel.setMethodCallHandler((MethodCall call) async {
      if (call.method != 'deliverBackgroundEvent') return;
      final PhoneCallEvent event =
          PhoneCallEvent.fromRaw(_asStringMap(call.arguments));
      await onEvent(event);
    });
  }

  @override
  Future<void> acknowledgeBackgroundEvent(String eventId) =>
      actionsChannel.invokeMethod<void>('ackBackgroundEvent', eventId);

  @override
  Future<void> notifyBackgroundDispatcherReady() =>
      actionsChannel.invokeMethod<void>('backgroundDispatcherReady');

  Future<CallControlResult> _invokeControl(
    String method, [
    Object? argument,
  ]) async {
    final Object? raw = await actionsChannel.invokeMethod(method, argument);
    return CallControlResult.fromRaw(_asStringMap(raw));
  }
}

/// Coerces a platform channel value into `Map<String, dynamic>`, throwing a
/// [PlatformException] with a predictable error code when the shape is wrong.
Map<String, dynamic> _asStringMap(Object? raw) {
  if (raw is Map) {
    return Map<String, dynamic>.from(raw);
  }
  throw PlatformException(
    code: 'malformed-payload',
    message: 'Expected a Map from the platform, got ${raw.runtimeType}.',
  );
}

/// Coerces a platform channel value into `List<Object?>`, throwing a
/// [PlatformException] with a predictable error code when the shape is wrong.
List<Object?> _asList(Object? raw) {
  if (raw is List) {
    return List<Object?>.from(raw);
  }
  throw PlatformException(
    code: 'malformed-payload',
    message: 'Expected a List from the platform, got ${raw.runtimeType}.',
  );
}
