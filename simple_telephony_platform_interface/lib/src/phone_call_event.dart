import 'package:flutter/foundation.dart';

import 'phone_call_base.dart';

/// Represents a phone call event emitted from the Android host layer.
class PhoneCallEvent with PhoneCallBase {
  PhoneCallEvent({
    this.eventId,
    required this.callId,
    required this.state,
    required this.isIncoming,
    this.phoneNumber,
    this.displayName,
    this.timestamp,
    this.disconnectCause,
    Map<String, dynamic>? extras,
  }) : extras = extras == null ? const {} : Map.unmodifiable(extras);

  /// Unique identifier for this emitted event.
  final String? eventId;

  @override
  final String callId;

  @override
  final String state;

  @override
  final bool isIncoming;

  @override
  final String? phoneNumber;

  @override
  final String? displayName;

  /// Epoch millis at which the event was emitted.
  final int? timestamp;

  @override
  final String? disconnectCause;

  /// Additional host supplied metadata.
  final Map<String, dynamic> extras;

  /// Convenience: returns a best-effort enum for the state.
  PhoneCallState get phoneCallState => PhoneCallStateX.fromPlatformValue(state);

  /// Convenience: returns a best-effort call direction enum.
  PhoneCallDirection get direction =>
      isIncoming ? PhoneCallDirection.incoming : PhoneCallDirection.outgoing;

  factory PhoneCallEvent.fromRaw(Map<String, dynamic> raw) {
    return PhoneCallEvent(
      eventId: raw['eventId']?.toString(),
      callId: raw['callId']?.toString() ?? '',
      state: (raw['state']?.toString() ?? 'unknown').toLowerCase(),
      isIncoming: raw['isIncoming'] == true,
      phoneNumber: raw['phoneNumber']?.toString(),
      displayName: raw['displayName']?.toString(),
      timestamp: int.tryParse(raw['timestamp']?.toString() ?? ''),
      disconnectCause: raw['disconnectCause']?.toString(),
      extras: (raw['extras'] is Map)
          ? Map<String, dynamic>.from(raw['extras'] as Map)
          : const {},
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'eventId': eventId,
        'callId': callId,
        'state': state,
        'isIncoming': isIncoming,
        'phoneNumber': phoneNumber,
        'displayName': displayName,
        'timestamp': timestamp,
        'disconnectCause': disconnectCause,
        'extras': extras,
      };

  @override
  String toString() =>
      'PhoneCallEvent(callId: $callId, state: $state, incoming: $isIncoming, number: $phoneNumber, displayName: $displayName, disconnectCause: $disconnectCause)';

  @override
  bool operator ==(Object other) {
    return other is PhoneCallEvent &&
        other.eventId == eventId &&
        other.callId == callId &&
        other.state == state &&
        other.isIncoming == isIncoming &&
        other.phoneNumber == phoneNumber &&
        other.displayName == displayName &&
        other.disconnectCause == disconnectCause &&
        mapEquals(other.extras, extras);
  }

  @override
  int get hashCode => Object.hashAll([
        callId,
        state,
        isIncoming,
        phoneNumber,
        displayName,
        disconnectCause,
        eventId,
        Object.hashAll(
          extras.entries
              .map((entry) => Object.hash(entry.key, entry.value))
              .toList(),
        ),
      ]);
}

enum PhoneCallState {
  newCall,
  ringing,
  dialing,
  connecting,
  active,
  holding,
  disconnecting,
  disconnected,
  unknown,
}

enum PhoneCallDirection { incoming, outgoing }

extension PhoneCallStateX on PhoneCallState {
  static PhoneCallState fromPlatformValue(String value) {
    switch (value.toLowerCase()) {
      case 'new':
      case 'new_call':
        return PhoneCallState.newCall;
      case 'ringing':
        return PhoneCallState.ringing;
      case 'dialing':
        return PhoneCallState.dialing;
      case 'connecting':
        return PhoneCallState.connecting;
      case 'active':
        return PhoneCallState.active;
      case 'holding':
      case 'on_hold':
        return PhoneCallState.holding;
      case 'disconnecting':
        return PhoneCallState.disconnecting;
      case 'disconnected':
        return PhoneCallState.disconnected;
      default:
        return PhoneCallState.unknown;
    }
  }
}
