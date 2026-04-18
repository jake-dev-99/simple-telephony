import 'package:flutter_test/flutter_test.dart';
import 'package:simple_telephony_platform_interface/simple_telephony_platform_interface.dart';

void main() {
  // ---------------------------------------------------------------------------
  // PhoneCallEvent
  // ---------------------------------------------------------------------------

  group('PhoneCallEvent', () {
    test('fromRaw decodes all fields', () {
      final event = PhoneCallEvent.fromRaw(<String, dynamic>{
        'eventId': 'evt-1',
        'callId': 'call-1',
        'state': 'ringing',
        'isIncoming': true,
        'phoneNumber': '+15551234567',
        'displayName': 'Alice',
        'timestamp': 1000,
        'disconnectCause': 'remote',
        'extras': <String, dynamic>{'key': 'value'},
      });

      expect(event.eventId, 'evt-1');
      expect(event.callId, 'call-1');
      expect(event.state, 'ringing');
      expect(event.isIncoming, isTrue);
      expect(event.phoneNumber, '+15551234567');
      expect(event.displayName, 'Alice');
      expect(event.timestamp, 1000);
      expect(event.disconnectCause, 'remote');
      expect(event.extras, {'key': 'value'});
    });

    test('fromRaw handles missing optional fields', () {
      final event = PhoneCallEvent.fromRaw(<String, dynamic>{
        'callId': 'call-2',
        'state': 'active',
        'isIncoming': false,
      });

      expect(event.eventId, isNull);
      expect(event.callId, 'call-2');
      expect(event.phoneNumber, isNull);
      expect(event.displayName, isNull);
      expect(event.timestamp, isNull);
      expect(event.disconnectCause, isNull);
      expect(event.extras, isEmpty);
    });

    test('fromRaw defaults to empty callId when missing', () {
      final event = PhoneCallEvent.fromRaw(<String, dynamic>{});
      expect(event.callId, '');
      expect(event.state, 'unknown');
      expect(event.isIncoming, isFalse);
    });

    test('fromRaw normalizes state to lowercase', () {
      final event = PhoneCallEvent.fromRaw(<String, dynamic>{
        'callId': 'c',
        'state': 'RINGING',
        'isIncoming': true,
      });
      expect(event.state, 'ringing');
      expect(event.phoneCallState, PhoneCallState.ringing);
    });

    test('toJson roundtrips correctly', () {
      final original = PhoneCallEvent(
        eventId: 'evt-rt',
        callId: 'call-rt',
        state: 'active',
        isIncoming: false,
        phoneNumber: '+1555',
        displayName: 'Bob',
        timestamp: 42,
        disconnectCause: null,
      );
      final json = original.toJson();
      final restored = PhoneCallEvent.fromRaw(
        Map<String, dynamic>.from(json),
      );

      expect(restored, equals(original));
    });

    test('equality compares all fields', () {
      final a = PhoneCallEvent(
        callId: 'c',
        state: 'active',
        isIncoming: true,
        eventId: 'e1',
      );
      final b = PhoneCallEvent(
        callId: 'c',
        state: 'active',
        isIncoming: true,
        eventId: 'e1',
      );
      final c = PhoneCallEvent(
        callId: 'c',
        state: 'active',
        isIncoming: true,
        eventId: 'e2', // different
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });

    test('extras map is unmodifiable', () {
      final event = PhoneCallEvent(
        callId: 'c',
        state: 's',
        isIncoming: false,
        extras: {'key': 'value'},
      );
      expect(
        () => event.extras['new'] = 'bad',
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // PhoneCallState mapping
  // ---------------------------------------------------------------------------

  group('PhoneCallState', () {
    test('all known states map correctly', () {
      expect(PhoneCallStateX.fromPlatformValue('new'), PhoneCallState.newCall);
      expect(PhoneCallStateX.fromPlatformValue('new_call'),
          PhoneCallState.newCall);
      expect(
          PhoneCallStateX.fromPlatformValue('ringing'), PhoneCallState.ringing);
      expect(
          PhoneCallStateX.fromPlatformValue('dialing'), PhoneCallState.dialing);
      expect(PhoneCallStateX.fromPlatformValue('connecting'),
          PhoneCallState.connecting);
      expect(
          PhoneCallStateX.fromPlatformValue('active'), PhoneCallState.active);
      expect(
          PhoneCallStateX.fromPlatformValue('holding'), PhoneCallState.holding);
      expect(
          PhoneCallStateX.fromPlatformValue('on_hold'), PhoneCallState.holding);
      expect(PhoneCallStateX.fromPlatformValue('disconnecting'),
          PhoneCallState.disconnecting);
      expect(PhoneCallStateX.fromPlatformValue('disconnected'),
          PhoneCallState.disconnected);
    });

    test('unknown states map to unknown', () {
      expect(
          PhoneCallStateX.fromPlatformValue('bogus'), PhoneCallState.unknown);
      expect(PhoneCallStateX.fromPlatformValue(''), PhoneCallState.unknown);
    });

    test('mapping is case-insensitive', () {
      expect(
          PhoneCallStateX.fromPlatformValue('ACTIVE'), PhoneCallState.active);
      expect(
          PhoneCallStateX.fromPlatformValue('Ringing'), PhoneCallState.ringing);
    });
  });

  // ---------------------------------------------------------------------------
  // PhoneCallDirection
  // ---------------------------------------------------------------------------

  group('PhoneCallDirection', () {
    test('incoming event returns incoming direction', () {
      final event = PhoneCallEvent(callId: 'c', state: 's', isIncoming: true);
      expect(event.direction, PhoneCallDirection.incoming);
    });

    test('outgoing event returns outgoing direction', () {
      final event = PhoneCallEvent(callId: 'c', state: 's', isIncoming: false);
      expect(event.direction, PhoneCallDirection.outgoing);
    });
  });

  // ---------------------------------------------------------------------------
  // PhoneCallSnapshot
  // ---------------------------------------------------------------------------

  group('PhoneCallSnapshot', () {
    test('fromRaw decodes all fields', () {
      final snapshot = PhoneCallSnapshot.fromRaw(<String, dynamic>{
        'callId': 'call-1',
        'state': 'active',
        'isIncoming': false,
        'createdAt': 100,
        'updatedAt': 200,
        'isLive': true,
        'pendingEventCount': 3,
        'phoneNumber': '+1555',
        'displayName': 'Charlie',
        'disconnectCause': 'local',
      });

      expect(snapshot.callId, 'call-1');
      expect(snapshot.state, 'active');
      expect(snapshot.isIncoming, isFalse);
      expect(snapshot.createdAt, 100);
      expect(snapshot.updatedAt, 200);
      expect(snapshot.isLive, isTrue);
      expect(snapshot.pendingEventCount, 3);
      expect(snapshot.phoneNumber, '+1555');
      expect(snapshot.displayName, 'Charlie');
      expect(snapshot.disconnectCause, 'local');
    });

    test('fromRaw handles missing optional fields with defaults', () {
      final snapshot = PhoneCallSnapshot.fromRaw(<String, dynamic>{});

      expect(snapshot.callId, '');
      expect(snapshot.state, 'unknown');
      expect(snapshot.isIncoming, isFalse);
      expect(snapshot.createdAt, 0);
      expect(snapshot.updatedAt, 0);
      expect(snapshot.isLive, isFalse);
      expect(snapshot.pendingEventCount, 0);
      expect(snapshot.phoneNumber, isNull);
      expect(snapshot.displayName, isNull);
      expect(snapshot.disconnectCause, isNull);
    });

    test('toJson roundtrips correctly', () {
      final original = PhoneCallSnapshot(
        callId: 'c',
        state: 'ringing',
        isIncoming: true,
        createdAt: 10,
        updatedAt: 20,
        isLive: true,
        pendingEventCount: 1,
        phoneNumber: '+1',
        displayName: 'D',
        disconnectCause: null,
      );
      final json = original.toJson();
      final restored = PhoneCallSnapshot.fromRaw(
        Map<String, dynamic>.from(json),
      );

      expect(restored, equals(original));
    });

    test('equality compares all fields', () {
      final a = PhoneCallSnapshot(
        callId: 'c',
        state: 's',
        isIncoming: true,
        createdAt: 1,
        updatedAt: 2,
        isLive: true,
        pendingEventCount: 0,
      );
      final b = PhoneCallSnapshot(
        callId: 'c',
        state: 's',
        isIncoming: true,
        createdAt: 1,
        updatedAt: 2,
        isLive: true,
        pendingEventCount: 0,
      );
      final c = PhoneCallSnapshot(
        callId: 'c',
        state: 's',
        isIncoming: true,
        createdAt: 1,
        updatedAt: 999, // different
        isLive: true,
        pendingEventCount: 0,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });

    test('implements PhoneCallBase mixin', () {
      final PhoneCallBase snapshot = PhoneCallSnapshot(
        callId: 'c',
        state: 'active',
        isIncoming: true,
        createdAt: 1,
        updatedAt: 2,
        isLive: true,
        pendingEventCount: 0,
        phoneNumber: '+1',
        displayName: 'Test',
        disconnectCause: null,
      );
      expect(snapshot.callId, 'c');
      expect(snapshot.state, 'active');
      expect(snapshot.isIncoming, isTrue);
      expect(snapshot.phoneNumber, '+1');
      expect(snapshot.displayName, 'Test');
      expect(snapshot.disconnectCause, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // CallControlResult
  // ---------------------------------------------------------------------------

  group('CallControlResult', () {
    test('fromRaw decodes all known statuses', () {
      for (final status in CallControlStatus.values) {
        final result = CallControlResult.fromRaw(<String, dynamic>{
          'status': status.name,
          'message': 'msg',
        });
        expect(result.status, status);
        expect(result.message, 'msg');
      }
    });

    test('fromRaw defaults unknown status to platformFailure', () {
      final result = CallControlResult.fromRaw(<String, dynamic>{
        'status': 'totallyNew',
      });
      expect(result.status, CallControlStatus.platformFailure);
    });

    test('fromRaw defaults null status to platformFailure', () {
      final result = CallControlResult.fromRaw(<String, dynamic>{});
      expect(result.status, CallControlStatus.platformFailure);
    });

    test('isSuccess is true for success', () {
      const r = CallControlResult(status: CallControlStatus.success);
      expect(r.isSuccess, isTrue);
    });

    test('isSuccess is true for requested', () {
      const r = CallControlResult(status: CallControlStatus.requested);
      expect(r.isSuccess, isTrue);
    });

    test('isSuccess is false for all error statuses', () {
      for (final status in CallControlStatus.values) {
        if (status == CallControlStatus.success ||
            status == CallControlStatus.requested) {
          continue;
        }
        final r = CallControlResult(status: status);
        expect(r.isSuccess, isFalse,
            reason: '${status.name} should not be success');
      }
    });

    test('toJson roundtrips correctly', () {
      const original = CallControlResult(
        status: CallControlStatus.notAttached,
        message: 'gone',
      );
      final json = original.toJson();
      final restored = CallControlResult.fromRaw(
        Map<String, dynamic>.from(json),
      );

      expect(restored, equals(original));
    });

    test('equality compares status and message', () {
      const a =
          CallControlResult(status: CallControlStatus.success, message: 'ok');
      const b =
          CallControlResult(status: CallControlStatus.success, message: 'ok');
      const c = CallControlResult(
          status: CallControlStatus.success, message: 'different');

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });
}
