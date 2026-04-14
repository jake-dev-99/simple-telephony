/// The kind of entry in the device call log.
enum CallType {
  /// An answered incoming call.
  incoming,

  /// A placed outgoing call.
  outgoing,

  /// An incoming call that was not answered.
  missed,

  /// An incoming call explicitly rejected by the user.
  rejected,

  /// A call blocked by the device/OS (e.g. number is blocklisted).
  blocked,

  /// A voicemail entry in the call log.
  voicemail,

  /// The underlying `CallLog.Calls.TYPE` value didn't map to a known case.
  unknown,
}

/// A single row in the device's call log, expressed as a typed plugin model
/// rather than a raw content-provider map.
///
/// Emitted by `SimpleTelephonyNative.instance.listCallLog(...)`.
class CallLogEntry {
  const CallLogEntry({
    required this.id,
    required this.type,
    required this.date,
    required this.duration,
    this.number,
    this.name,
    this.isNew = false,
    this.isRead = false,
    this.geocodedLocation,
    this.subscriptionId,
    this.sourceMap,
  });

  /// Content-provider row id (`_id`).
  final int id;

  /// Remote phone number / address on the call, if available.
  final String? number;

  /// Cached display name from the contacts book at the time of the call,
  /// if available (not live-resolved).
  final String? name;

  /// Direction / outcome of the call.
  final CallType type;

  /// Wall-clock time the call occurred.
  final DateTime date;

  /// Total duration of the call. Zero for missed/rejected calls.
  final Duration duration;

  /// True when this row is new (not yet surfaced to the user).
  final bool isNew;

  /// True when the row has been marked read.
  final bool isRead;

  /// Coarse geocoded location string Android sometimes caches.
  final String? geocodedLocation;

  /// Subscription id of the SIM that placed/received the call, if known.
  final int? subscriptionId;

  /// The raw underlying row (every column) for edge-case consumers that
  /// need access to non-modeled fields.
  final Map<String, Object?>? sourceMap;

  @override
  String toString() => 'CallLogEntry(id: $id, type: $type, number: $number, '
      'date: $date, duration: $duration)';
}
