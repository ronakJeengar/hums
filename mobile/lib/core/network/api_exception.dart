/// Standardized API Exception parsed from the Hums error envelope
class ApiException implements Exception {
  final String code;
  final String message;
  final Map<String, dynamic> details;
  final int? statusCode;

  const ApiException({
    required this.code,
    required this.message,
    this.details = const {},
    this.statusCode,
  });

  factory ApiException.fromResponse(Map<String, dynamic> json, int? statusCode) {
    if (json.containsKey('error') && json['error'] is Map<String, dynamic>) {
      final errorMap = json['error'] as Map<String, dynamic>;
      return ApiException(
        code: errorMap['code'] as String? ?? 'UNKNOWN_ERROR',
        message: errorMap['message'] as String? ?? 'An unexpected error occurred.',
        details: (errorMap['details'] as Map<String, dynamic>?) ?? {},
        statusCode: statusCode,
      );
    }
    return ApiException(
      code: 'PARSING_ERROR',
      message: 'Failed to parse error response from server.',
      statusCode: statusCode,
    );
  }

  factory ApiException.network(String message) {
    return ApiException(
      code: 'NETWORK_ERROR',
      message: message,
    );
  }

  @override
  String toString() => 'ApiException [$code]: $message (Status: $statusCode)';
}
