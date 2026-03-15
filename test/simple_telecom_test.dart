import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_telephony/simple_telephony.dart';

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
          return <String, Object?>{'status': 'success'};
        case 'initializeForeground':
          return null;
        default:
          return null;
      }
    });
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(_actionsChannel, null);
  });

  test(
      'registerBackgroundHandler stores callback handles through native bridge',
      () async {
    await SimpleTelecom.registerBackgroundHandler(_backgroundHandler);

    expect(recordedCalls, hasLength(1));
    expect(recordedCalls.single.method, 'registerBackgroundHandler');

    final Map<Object?, Object?> args =
        recordedCalls.single.arguments as Map<Object?, Object?>;
    expect(args['dispatcherHandle'], isA<int>());
    expect(args['handlerHandle'], isA<int>());
  });

  test('getCurrentCalls decodes persisted snapshots', () async {
    final calls = await SimpleTelecom.instance.getCurrentCalls();

    expect(calls, hasLength(1));
    expect(calls.single.callId, 'call-1');
    expect(calls.single.state, 'ringing');
    expect(calls.single.isIncoming, isTrue);
  });

  test('placePhoneCall decodes typed control results', () async {
    final result = await SimpleTelecom.instance.placePhoneCall('+15551234567');

    expect(result.isSuccess, isTrue);
    expect(result.status, CallControlStatus.success);
  });

  test('events emits decoded foreground events', () async {
    messenger.setMockMethodCallHandler(
      const MethodChannel('io.simplezen.simple_telephony/foreground_events'),
      (MethodCall call) async => null,
    );

    final Completer<PhoneCallEvent> completer = Completer<PhoneCallEvent>();
    final subscription =
        SimpleTelecom.instance.events.listen(completer.complete);

    final ByteData? envelope =
        const StandardMethodCodec().encodeSuccessEnvelope(
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
}
