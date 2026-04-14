import 'phone_call_base.dart';

/// A point-in-time snapshot of a call's persisted state on the native side.
///
/// Retrieved via [SimpleTelephony.getCurrentCalls]. Unlike [PhoneCallEvent],
/// a snapshot includes persistence metadata like [createdAt], [updatedAt],
/// [isLive], and [pendingEventCount].
class PhoneCallSnapshot with PhoneCallBase {
  PhoneCallSnapshot({
    required this.callId,
    required this.state,
    required this.isIncoming,
    required this.createdAt,
    required this.updatedAt,
    required this.isLive,
    required this.pendingEventCount,
    this.phoneNumber,
    this.displayName,
    this.disconnectCause,
  });

  @override
  final String callId;
  @override
  final String state;
  @override
  final bool isIncoming;
  final int createdAt;
  final int updatedAt;
  final bool isLive;
  final int pendingEventCount;
  @override
  final String? phoneNumber;
  @override
  final String? displayName;
  @override
  final String? disconnectCause;

  factory PhoneCallSnapshot.fromRaw(Map<String, dynamic> raw) {
    return PhoneCallSnapshot(
      callId: raw['callId']?.toString() ?? '',
      state: raw['state']?.toString() ?? 'unknown',
      isIncoming: raw['isIncoming'] == true,
      createdAt: int.tryParse(raw['createdAt']?.toString() ?? '') ?? 0,
      updatedAt: int.tryParse(raw['updatedAt']?.toString() ?? '') ?? 0,
      isLive: raw['isLive'] == true,
      pendingEventCount:
          int.tryParse(raw['pendingEventCount']?.toString() ?? '') ?? 0,
      phoneNumber: raw['phoneNumber']?.toString(),
      displayName: raw['displayName']?.toString(),
      disconnectCause: raw['disconnectCause']?.toString(),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'callId': callId,
        'state': state,
        'isIncoming': isIncoming,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'isLive': isLive,
        'pendingEventCount': pendingEventCount,
        'phoneNumber': phoneNumber,
        'displayName': displayName,
        'disconnectCause': disconnectCause,
      };

  @override
  bool operator ==(Object other) =>
      other is PhoneCallSnapshot &&
      other.callId == callId &&
      other.state == state &&
      other.isIncoming == isIncoming &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.isLive == isLive &&
      other.pendingEventCount == pendingEventCount &&
      other.phoneNumber == phoneNumber &&
      other.displayName == displayName &&
      other.disconnectCause == disconnectCause;

  @override
  int get hashCode => Object.hash(
        callId,
        state,
        isIncoming,
        createdAt,
        updatedAt,
        isLive,
        pendingEventCount,
        phoneNumber,
        displayName,
        disconnectCause,
      );
}
