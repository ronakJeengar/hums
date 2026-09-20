enum PlayerErrorType {
  sourceUnavailable,
  networkError,
  unauthorized,
  audioLoadFailed,
  decodingFailed,
  unknown,
}

class PlayerError {
  final PlayerErrorType type;
  final String message;
  final String? details;

  const PlayerError({
    required this.type,
    required this.message,
    this.details,
  });

  @override
  String toString() => 'PlayerError(type: $type, message: $message, details: $details)';
}
