/// Outcome of a call control operation (answer, end, or place).
enum CallControlStatus {
  success,
  requested,
  notFound,
  notAttached,
  permissionDenied,
  platformFailure,
  invalidArguments,
}

/// Result of a call control operation, carrying a [status] and optional [message].
///
/// Check [isSuccess] for a quick pass/fail, or inspect [status] for
/// granular error handling.
class CallControlResult {
  const CallControlResult({
    required this.status,
    this.message,
  });

  final CallControlStatus status;
  final String? message;

  bool get isSuccess =>
      status == CallControlStatus.success ||
      status == CallControlStatus.requested;

  factory CallControlResult.fromRaw(Map<String, dynamic> raw) {
    return CallControlResult(
      status: _statusFromString(raw['status']?.toString()),
      message: raw['message']?.toString(),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'status': status.name,
        'message': message,
      };

  @override
  bool operator ==(Object other) =>
      other is CallControlResult &&
      other.status == status &&
      other.message == message;

  @override
  int get hashCode => Object.hash(status, message);

  static CallControlStatus _statusFromString(String? raw) {
    switch (raw) {
      case 'success':
        return CallControlStatus.success;
      case 'requested':
        return CallControlStatus.requested;
      case 'notFound':
        return CallControlStatus.notFound;
      case 'notAttached':
        return CallControlStatus.notAttached;
      case 'permissionDenied':
        return CallControlStatus.permissionDenied;
      case 'platformFailure':
        return CallControlStatus.platformFailure;
      case 'invalidArguments':
        return CallControlStatus.invalidArguments;
      default:
        return CallControlStatus.platformFailure;
    }
  }
}
