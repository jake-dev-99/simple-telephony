library simple_telephony;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import 'src/phone_call_event.dart';

export 'src/phone_call_event.dart';

typedef CallEventHandler = Future<bool> Function(PhoneCallEvent event);

/// High-level facade for interacting with the Android telephony bridge.
class SimpleTelecom {
  SimpleTelecom._();

  static final SimpleTelecom instance = SimpleTelecom._();

  static const MethodChannel _actionsChannel =
      MethodChannel('io.simplezen.simple_telephony/telecom_actions');
  static const MethodChannel _inboundChannel =
      MethodChannel('io.simplezen.simple_telephony/inbound');

  static CallEventHandler? _callEventHandler;
  static bool _initialized = false;

  /// Wires the inbound method channel so call events can be surfaced to Dart.
  static Future<void> initialize({
    required CallEventHandler onCallEvent,
  }) async {
    _callEventHandler = onCallEvent;
    if (_initialized) {
      return;
    }
    _inboundChannel.setMethodCallHandler(_handleInboundCallMethod);
    _initialized = true;
  }

  /// Places an outbound phone call using [phoneNumber].
  Future<bool> placePhoneCall(String phoneNumber) async =>
      _invokeBool('placePhoneCall', phoneNumber);

  /// Attempts to answer the call represented by [callId].
  Future<bool> answerPhoneCall(String callId) async =>
      _invokeBool('answerPhoneCall', callId);

  /// Attempts to hang up the call represented by [callId].
  Future<bool> endPhoneCall(String callId) async =>
      _invokeBool('endPhoneCall', callId);

  /// Returns whether this app currently holds the default dialer role.
  Future<bool> isDefaultDialerApp() async =>
      _invokeBool('isDefaultDialerApp', null);

  /// Requests the default dialer role. Returns true if granted.
  Future<bool> requestDefaultDialerApp() async =>
      _invokeBool('requestDefaultDialerApp', null);

  Future<bool> _invokeBool(String method, [Object? argument]) async {
    final dynamic result = await _actionsChannel.invokeMethod(method, argument);
    return result == true;
  }

  static Future<bool> _handleInboundCallMethod(MethodCall call) async {
    if (call.method != 'receiveCallEvent') {
      return false;
    }

    final handler = _callEventHandler;
    if (handler == null) {
      return false;
    }

    if (call.arguments is! String) {
      throw PlatformException(
        code: 'INVALID_ARGUMENT_TYPE',
        message:
            'Expected a JSON-encoded payload for receiveCallEvent but got ${call.arguments.runtimeType}',
      );
    }

    final Map<String, dynamic> decoded =
        jsonDecode(call.arguments as String) as Map<String, dynamic>;
    final event = PhoneCallEvent.fromRaw(decoded);
    return await handler(event);
  }
}
