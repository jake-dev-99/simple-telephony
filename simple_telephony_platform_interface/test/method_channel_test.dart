import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_telephony_platform_interface/simple_telephony_platform_interface.dart';

const MethodChannel _actionsChannel =
    MethodChannel(actionsChannelName);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late MethodChannelSimpleTelephony platform;

  setUp(() {
    platform = MethodChannelSimpleTelephony();
    messenger.setMockMethodCallHandler(_actionsChannel,
        (MethodCall call) async {
      switch (call.method) {
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
        case 'registerBackgroundHandler':
          return null;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(_actionsChannel, null);
  });

  test('getCurrentCalls decodes persisted snapshots', () async {
    final calls = await platform.getCurrentCalls();
    expect(calls, hasLength(1));
    expect(calls.single.callId, 'call-1');
    expect(calls.single.state, 'ringing');
  });

  test('getCurrentCalls returns empty list when native returns null', () async {
    messenger.setMockMethodCallHandler(_actionsChannel,
        (MethodCall call) async => null);
    final calls = await platform.getCurrentCalls();
    expect(calls, isEmpty);
  });

  test('placePhoneCall returns requested status', () async {
    final result = await platform.placePhoneCall('+15551234567');
    expect(result.isSuccess, isTrue);
    expect(result.status, CallControlStatus.requested);
  });

  test('answerPhoneCall returns success', () async {
    final result = await platform.answerPhoneCall('call-1');
    expect(result.isSuccess, isTrue);
    expect(result.status, CallControlStatus.success);
  });

  test('answerPhoneCall decodes notAttached', () async {
    messenger.setMockMethodCallHandler(_actionsChannel,
        (MethodCall call) async => <String, Object?>{
              'status': 'notAttached',
              'message': 'Call record exists but live call is not attached',
            });
    final result = await platform.answerPhoneCall('call-stale');
    expect(result.isSuccess, isFalse);
    expect(result.status, CallControlStatus.notAttached);
  });

  test('endPhoneCall returns success', () async {
    final result = await platform.endPhoneCall('call-1');
    expect(result.isSuccess, isTrue);
  });

  test('registerBackgroundHandler sends handles', () async {
    final List<MethodCall> calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(_actionsChannel,
        (MethodCall call) async {
      calls.add(call);
      return null;
    });

    await platform.registerBackgroundHandler(
        dispatcherHandle: 111, userHandle: 222);

    expect(calls, hasLength(1));
    expect(calls.single.method, 'registerBackgroundHandler');
    final args = calls.single.arguments as Map<Object?, Object?>;
    expect(args['dispatcherHandle'], 111);
    expect(args['handlerHandle'], 222);
  });

  test('unknown control status maps to platformFailure', () async {
    messenger.setMockMethodCallHandler(_actionsChannel,
        (MethodCall call) async => <String, Object?>{'status': 'future_status'});
    final result = await platform.endPhoneCall('call-1');
    expect(result.status, CallControlStatus.platformFailure);
  });
}
