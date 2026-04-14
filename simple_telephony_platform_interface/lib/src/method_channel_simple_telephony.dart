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
  final MethodChannel actionsChannel =
      const MethodChannel(actionsChannelName);

  /// The event channel for foreground call events.
  final EventChannel foregroundEventsChannel =
      const EventChannel(foregroundEventsChannelName);

  /// The method channel for background event delivery.
  final MethodChannel backgroundEventsChannel =
      const MethodChannel(backgroundEventsChannelName);

  Stream<PhoneCallEvent>? _events;

  @override
  Stream<PhoneCallEvent> get events =>
      _events ??= foregroundEventsChannel
          .receiveBroadcastStream()
          .map((dynamic event) {
        return PhoneCallEvent.fromRaw(Map<String, dynamic>.from(event as Map));
      }).asBroadcastStream();

  @override
  Future<List<PhoneCallSnapshot>> getCurrentCalls() async {
    final List<dynamic> rawCalls =
        await actionsChannel.invokeMethod<List<dynamic>>('getCurrentCalls') ??
            const <dynamic>[];

    return rawCalls
        .map(
          (dynamic raw) => PhoneCallSnapshot.fromRaw(
            Map<String, dynamic>.from(raw as Map),
          ),
        )
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
  Future<bool> isDefaultDialerApp() async =>
      (await actionsChannel.invokeMethod<bool>('isDefaultDialerApp')) == true;

  @override
  Future<bool> requestDefaultDialerApp() async =>
      (await actionsChannel.invokeMethod<bool>('requestDefaultDialerApp')) ==
      true;

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

  Future<CallControlResult> _invokeControl(
    String method, [
    Object? argument,
  ]) async {
    final dynamic raw = await actionsChannel.invokeMethod(method, argument);
    return CallControlResult.fromRaw(Map<String, dynamic>.from(raw as Map));
  }
}
