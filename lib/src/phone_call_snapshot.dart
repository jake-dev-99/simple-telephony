class PhoneCallSnapshot {
  const PhoneCallSnapshot({
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

  final String callId;
  final String state;
  final bool isIncoming;
  final int createdAt;
  final int updatedAt;
  final bool isLive;
  final int pendingEventCount;
  final String? phoneNumber;
  final String? displayName;
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
}
