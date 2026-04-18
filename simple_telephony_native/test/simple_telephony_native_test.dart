import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_telephony_native/simple_telephony_native.dart';

const MethodChannel _actionsChannel =
    MethodChannel('io.simplezen.simple_telephony/telecom_actions');
const EventChannel _foregroundChannel =
    EventChannel('io.simplezen.simple_telephony/foreground_events');

@pragma('vm:entry-point')
Future<void> _backgroundHandler(PhoneCallEvent event) async {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final List<MethodCall> recordedCalls = <MethodCall>[];

  ByteData encodeSuccessEnvelope(Map<String, Object?> payload) =>
      const StandardMethodCodec().encodeSuccessEnvelope(payload);

  Future<void> emitForegroundEvent(Map<String, Object?> payload) async {
    messenger.handlePlatformMessage(
      _foregroundChannel.name,
      encodeSuccessEnvelope(payload),
      (_) {},
    );
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() {
    recordedCalls.clear();
    messenger.setMockMethodCallHandler(_actionsChannel,
        (MethodCall call) async {
      recordedCalls.add(call);
      switch (call.method) {
        case 'registerBackgroundHandler':
          return null;
        case 'getCurrentCalls':
          return <Object?>[
            <String, Object?>{
              'callId': 'call-1',
              'state': 'ringing',
              'isIncoming': true,
              'createdAt': 1,
              'updatedAt': 2,
              'isLive': true,
              'pendingEventCount': 0,
            },
          ];
        case 'placePhoneCall':
          return <String, Object?>{'status': 'requested'};
        case 'answerPhoneCall':
          return <String, Object?>{'status': 'success'};
        case 'endPhoneCall':
          return <String, Object?>{'status': 'success'};
        default:
          return null;
      }
    });
  });

  tearDown(() async {
    await SimpleTelephonyNative.disposeForegroundListener();
    messenger.setMockMethodCallHandler(_actionsChannel, null);
  });

  // ---------------------------------------------------------------------------
  // Registration
  // ---------------------------------------------------------------------------

  test(
      'registerBackgroundHandler stores callback handles through native bridge',
      () async {
    await SimpleTelephonyNative.registerBackgroundHandler(_backgroundHandler);

    expect(recordedCalls, hasLength(1));
    expect(recordedCalls.single.method, 'registerBackgroundHandler');

    final Map<Object?, Object?> args =
        recordedCalls.single.arguments as Map<Object?, Object?>;
    expect(args['dispatcherHandle'], isA<int>());
    expect(args['handlerHandle'], isA<int>());
  });

  // ---------------------------------------------------------------------------
  // getCurrentCalls
  // ---------------------------------------------------------------------------

  test('getCurrentCalls decodes persisted snapshots', () async {
    final calls = await SimpleTelephonyNative.instance.getCurrentCalls();

    expect(calls, hasLength(1));
    expect(calls.single.callId, 'call-1');
    expect(calls.single.state, 'ringing');
    expect(calls.single.isIncoming, isTrue);
  });

  test('getCurrentCalls returns empty list when native returns null', () async {
    messenger.setMockMethodCallHandler(_actionsChannel,
        (MethodCall call) async {
      if (call.method == 'getCurrentCalls') return null;
      return null;
    });

    final calls = await SimpleTelephonyNative.instance.getCurrentCalls();
    expect(calls, isEmpty);
  });

  // ---------------------------------------------------------------------------
  // Call control: placePhoneCall
  // ---------------------------------------------------------------------------

  test('placePhoneCall decodes typed control results', () async {
    final result =
        await SimpleTelephonyNative.instance.placePhoneCall('+15551234567');

    expect(result.isSuccess, isTrue);
    expect(result.status, CallControlStatus.requested);
  });

  test('placePhoneCall passes phone number as argument', () async {
    await SimpleTelephonyNative.instance.placePhoneCall('+15559876543');

    final placeCall =
        recordedCalls.firstWhere((c) => c.method == 'placePhoneCall');
    expect(placeCall.arguments, '+15559876543');
  });

  // ---------------------------------------------------------------------------
  // Call control: answerPhoneCall
  // ---------------------------------------------------------------------------

  test('answerPhoneCall returns success for live call', () async {
    final result =
        await SimpleTelephonyNative.instance.answerPhoneCall('call-live');

    expect(result.isSuccess, isTrue);
    expect(result.status, CallControlStatus.success);
    final answerCall =
        recordedCalls.firstWhere((c) => c.method == 'answerPhoneCall');
    expect(answerCall.arguments, 'call-live');
  });

  test('answerPhoneCall decodes notAttached status', () async {
    messenger.setMockMethodCallHandler(_actionsChannel,
        (MethodCall call) async {
      if (call.method == 'answerPhoneCall') {
        return <String, Object?>{
          'status': 'notAttached',
          'message': 'Call record exists but live call is not attached',
        };
      }
      return null;
    });

    final result =
        await SimpleTelephonyNative.instance.answerPhoneCall('call-stale');

    expect(result.isSuccess, isFalse);
    expect(result.status, CallControlStatus.notAttached);
    expect(result.message, contains('not attached'));
  });

  test('answerPhoneCall decodes notFound status', () async {
    messenger.setMockMethodCallHandler(_actionsChannel,
        (MethodCall call) async {
      if (call.method == 'answerPhoneCall') {
        return <String, Object?>{
          'status': 'notFound',
          'message': 'Unknown callId',
        };
      }
      return null;
    });

    final result =
        await SimpleTelephonyNative.instance.answerPhoneCall('call-unknown');

    expect(result.isSuccess, isFalse);
    expect(result.status, CallControlStatus.notFound);
  });

  // ---------------------------------------------------------------------------
  // Call control: endPhoneCall
  // ---------------------------------------------------------------------------

  test('endPhoneCall returns success for live call', () async {
    final result =
        await SimpleTelephonyNative.instance.endPhoneCall('call-live');

    expect(result.isSuccess, isTrue);
    expect(result.status, CallControlStatus.success);
    final endCall = recordedCalls.firstWhere((c) => c.method == 'endPhoneCall');
    expect(endCall.arguments, 'call-live');
  });

  test('endPhoneCall decodes platformFailure status', () async {
    messenger.setMockMethodCallHandler(_actionsChannel,
        (MethodCall call) async {
      if (call.method == 'endPhoneCall') {
        return <String, Object?>{
          'status': 'platformFailure',
          'message': 'System error ending call',
        };
      }
      return null;
    });

    final result =
        await SimpleTelephonyNative.instance.endPhoneCall('call-fail');

    expect(result.isSuccess, isFalse);
    expect(result.status, CallControlStatus.platformFailure);
    expect(result.message, isNotNull);
  });

  // Default-dialer role tests live in simple_permissions_native's
  // suite; the role API moved out of this plugin in v0.4.0.

  // ---------------------------------------------------------------------------
  // Native error envelopes
  // ---------------------------------------------------------------------------

  test('method channel PlatformException propagates to caller', () async {
    messenger.setMockMethodCallHandler(_actionsChannel,
        (MethodCall call) async {
      if (call.method == 'answerPhoneCall') {
        throw PlatformException(
          code: 'invalid-args',
          message: 'callId is required',
        );
      }
      return null;
    });

    expect(
      () => SimpleTelephonyNative.instance.answerPhoneCall(''),
      throwsA(isA<PlatformException>()),
    );
  });

  test('unknown control status maps to platformFailure', () async {
    messenger.setMockMethodCallHandler(_actionsChannel,
        (MethodCall call) async {
      if (call.method == 'endPhoneCall') {
        return <String, Object?>{'status': 'some_future_status'};
      }
      return null;
    });

    final result = await SimpleTelephonyNative.instance.endPhoneCall('call-1');
    expect(result.status, CallControlStatus.platformFailure);
  });

  // ---------------------------------------------------------------------------
  // Foreground events
  // ---------------------------------------------------------------------------

  test('events emits decoded foreground events', () async {
    messenger.setMockMethodCallHandler(
      const MethodChannel('io.simplezen.simple_telephony/foreground_events'),
      (MethodCall call) async => null,
    );

    final Completer<PhoneCallEvent> completer = Completer<PhoneCallEvent>();
    final subscription =
        SimpleTelephonyNative.instance.events.listen(completer.complete);

    final ByteData envelope = encodeSuccessEnvelope(
      <String, Object?>{
        'eventId': 'evt-1',
        'callId': 'call-2',
        'state': 'active',
        'isIncoming': false,
        'timestamp': 99,
      },
    );

    messenger.handlePlatformMessage(
      _foregroundChannel.name,
      envelope,
      (_) {},
    );

    final PhoneCallEvent event = await completer.future;
    expect(event.eventId, 'evt-1');
    expect(event.callId, 'call-2');
    expect(event.phoneCallState, PhoneCallState.active);

    await subscription.cancel();
    messenger.setMockMethodCallHandler(
      const MethodChannel('io.simplezen.simple_telephony/foreground_events'),
      null,
    );
  });

  test('initializeForeground replaces existing listener deterministically',
      () async {
    messenger.setMockMethodCallHandler(
      const MethodChannel('io.simplezen.simple_telephony/foreground_events'),
      (MethodCall call) async => null,
    );

    final List<String> firstListenerCalls = <String>[];
    final List<String> secondListenerCalls = <String>[];

    await SimpleTelephonyNative.initializeForeground(
      onCallEvent: (PhoneCallEvent event) async {
        firstListenerCalls.add(event.callId);
      },
    );
    await SimpleTelephonyNative.initializeForeground(
      onCallEvent: (PhoneCallEvent event) async {
        secondListenerCalls.add(event.callId);
      },
    );

    await emitForegroundEvent(<String, Object?>{
      'eventId': 'evt-2',
      'callId': 'call-replaced',
      'state': 'ringing',
      'isIncoming': true,
      'timestamp': 100,
    });

    expect(firstListenerCalls, isEmpty);
    expect(secondListenerCalls, <String>['call-replaced']);

    messenger.setMockMethodCallHandler(
      const MethodChannel('io.simplezen.simple_telephony/foreground_events'),
      null,
    );
  });

  test('disposeForegroundListener stops foreground callbacks', () async {
    messenger.setMockMethodCallHandler(
      const MethodChannel('io.simplezen.simple_telephony/foreground_events'),
      (MethodCall call) async => null,
    );

    final List<String> observedCallIds = <String>[];
    await SimpleTelephonyNative.initializeForeground(
      onCallEvent: (PhoneCallEvent event) async {
        observedCallIds.add(event.callId);
      },
    );

    await SimpleTelephonyNative.disposeForegroundListener();
    await emitForegroundEvent(<String, Object?>{
      'eventId': 'evt-3',
      'callId': 'call-after-dispose',
      'state': 'active',
      'isIncoming': false,
      'timestamp': 101,
    });

    expect(observedCallIds, isEmpty);

    messenger.setMockMethodCallHandler(
      const MethodChannel('io.simplezen.simple_telephony/foreground_events'),
      null,
    );
  });

  test('foreground callback errors are reported without stopping later events',
      () async {
    messenger.setMockMethodCallHandler(
      const MethodChannel('io.simplezen.simple_telephony/foreground_events'),
      (MethodCall call) async => null,
    );

    final List<String> observedCallIds = <String>[];
    final List<FlutterErrorDetails> capturedErrors = <FlutterErrorDetails>[];
    final FlutterExceptionHandler? originalOnError = FlutterError.onError;
    FlutterError.onError = capturedErrors.add;

    addTearDown(() {
      FlutterError.onError = originalOnError;
    });

    var shouldThrow = true;
    await SimpleTelephonyNative.initializeForeground(
      onCallEvent: (PhoneCallEvent event) async {
        observedCallIds.add(event.callId);
        if (shouldThrow) {
          shouldThrow = false;
          throw StateError('boom');
        }
      },
    );

    await emitForegroundEvent(<String, Object?>{
      'eventId': 'evt-4',
      'callId': 'call-error',
      'state': 'ringing',
      'isIncoming': true,
      'timestamp': 102,
    });
    await emitForegroundEvent(<String, Object?>{
      'eventId': 'evt-5',
      'callId': 'call-after-error',
      'state': 'active',
      'isIncoming': true,
      'timestamp': 103,
    });

    expect(observedCallIds, <String>['call-error', 'call-after-error']);
    expect(capturedErrors, hasLength(1));
    expect(capturedErrors.single.exception, isA<StateError>());

    messenger.setMockMethodCallHandler(
      const MethodChannel('io.simplezen.simple_telephony/foreground_events'),
      null,
    );
  });
}
