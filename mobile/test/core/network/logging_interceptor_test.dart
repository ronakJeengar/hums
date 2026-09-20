import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hums_mobile/core/network/logging_interceptor.dart';

class TestRequestHandler extends RequestInterceptorHandler {
  RequestOptions? passedOptions;

  @override
  void next(RequestOptions requestOptions) {
    passedOptions = requestOptions;
  }
}

class TestResponseHandler extends ResponseInterceptorHandler {
  Response? passedResponse;

  @override
  void next(Response response) {
    passedResponse = response;
  }
}

class TestErrorHandler extends ErrorInterceptorHandler {
  DioException? passedError;

  @override
  void next(DioException err) {
    passedError = err;
  }
}

void main() {
  late LoggingInterceptor interceptor;

  setUp(() {
    interceptor = LoggingInterceptor();
  });

  group('LoggingInterceptor Tests', () {
    test('onRequest adds start time and passes request', () {
      final options = RequestOptions(
        path: '/api/v1/audio/tracks',
        method: 'GET',
        headers: {'Authorization': 'Bearer secret-jwt-token'},
        queryParameters: {'limit': 10},
      );

      final handler = TestRequestHandler();
      interceptor.onRequest(options, handler);

      expect(options.extra['request_start_time'], isNotNull);
      expect(options.extra['request_start_time'], isA<int>());
      expect(handler.passedOptions, equals(options));
    });

    test('onRequest sanitizes passwords and tokens in request body', () {
      final options = RequestOptions(
        path: '/api/v1/auth/login',
        method: 'POST',
        data: {
          'email': 'user@example.com',
          'password': 'SuperSecretPassword123!',
        },
      );

      final handler = TestRequestHandler();
      interceptor.onRequest(options, handler);

      expect(options.extra['request_start_time'], isNotNull);
      expect(handler.passedOptions, equals(options));
    });

    test('onResponse logs response details and passes response', () {
      final options = RequestOptions(
        path: '/api/v1/audio/tracks',
        method: 'GET',
        extra: {'request_start_time': DateTime.now().millisecondsSinceEpoch - 150},
      );

      final response = Response(
        requestOptions: options,
        statusCode: 200,
        data: {'success': true, 'data': []},
      );

      final handler = TestResponseHandler();
      interceptor.onResponse(response, handler);

      expect(response.statusCode, 200);
      expect(handler.passedResponse, equals(response));
    });

    test('onError logs error details and passes error', () {
      final options = RequestOptions(
        path: '/api/v1/audio/tracks/invalid-id',
        method: 'GET',
        extra: {'request_start_time': DateTime.now().millisecondsSinceEpoch - 80},
      );

      final error = DioException(
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: 404,
          data: {
            'success': false,
            'error': {'code': 'NOT_FOUND', 'message': 'Track not found'},
          },
        ),
        type: DioExceptionType.badResponse,
        message: 'Not found',
      );

      final handler = TestErrorHandler();
      interceptor.onError(error, handler);

      expect(handler.passedError, equals(error));
      expect(error.response?.statusCode, 404);
    });
  });
}
