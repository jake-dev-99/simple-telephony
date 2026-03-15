enum CallControlStatus {
  success,
  notFound,
  notAttached,
  permissionDenied,
  platformFailure,
  invalidArguments,
}

class CallControlResult {
  const CallControlResult({
    required this.status,
    this.message,
  });

  final CallControlStatus status;
  final String? message;

  bool get isSuccess => status == CallControlStatus.success;

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

  static CallControlStatus _statusFromString(String? raw) {
    switch (raw) {
      case 'success':
        return CallControlStatus.success;
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
