import 'package:flutter_test/flutter_test.dart';
import 'package:hums_mobile/core/network/api_exception.dart';

void main() {
  group('API Exception Parsing Tests', () {
    test('Correctly parses backend standard error envelope', () {
      final jsonResponse = {
        'success': false,
        'error': {
          'code': 'UNAUTHORIZED',
          'message': 'Token has expired',
          'details': {'field': 'token'},
        },
      };

      final exception = ApiException.fromResponse(jsonResponse, 401);
      expect(exception.code, 'UNAUTHORIZED');
      expect(exception.message, 'Token has expired');
      expect(exception.statusCode, 401);
      expect(exception.details['field'], 'token');
    });

    test('Falls back gracefully for non-standard error structures', () {
      final malformed = {'message': 'Server is down'};
      final exception = ApiException.fromResponse(malformed, 500);

      expect(exception.code, 'PARSING_ERROR');
      expect(exception.statusCode, 500);
    });

    test('Constructs network error exception', () {
      final exception = ApiException.network('Socket connection timed out');
      expect(exception.code, 'NETWORK_ERROR');
      expect(exception.message, 'Socket connection timed out');
    });
  });
}
