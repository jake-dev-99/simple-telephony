/// Shared fields present on both [PhoneCallEvent] and [PhoneCallSnapshot].
mixin PhoneCallBase {
  /// Platform-provided identifier for the call instance.
  String get callId;

  /// Normalised state string (e.g. `ringing`, `active`, `disconnected`).
  String get state;

  /// Whether the call was initiated by a remote party.
  bool get isIncoming;

  /// Normalised phone number / handle (if available).
  String? get phoneNumber;

  /// Display name resolved by the platform (may be null).
  String? get displayName;

  /// Disconnect cause, provided only for terminal events.
  String? get disconnectCause;
}
