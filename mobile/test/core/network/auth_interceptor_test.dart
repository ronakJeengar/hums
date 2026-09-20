import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hums_mobile/core/network/auth_interceptor.dart';
import 'package:hums_mobile/features/auth/data/datasources/auth_local_data_source.dart';

void main() {
  late AuthLocalDataSource localDataSource;
  late AuthInterceptor interceptor;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    localDataSource = AuthLocalDataSourceImpl(const FlutterSecureStorage());
    interceptor = AuthInterceptor(localDataSource);
  });

  group('AuthInterceptor Tests', () {
    test('attaches Authorization header when access token is stored', () async {
      await localDataSource.saveTokens(
        accessToken: 'saved-access-token',
        refreshToken: 'saved-refresh-token',
      );

      final options = RequestOptions(path: '/api/v1/tracks');
      final handler = RequestInterceptorHandler();

      // We can intercept onRequest
      await interceptor.onRequest(options, handler);

      expect(options.headers['Authorization'], 'Bearer saved-access-token');
    });

    test('bypasses Authorization header on login and register endpoints', () async {
      await localDataSource.saveTokens(
        accessToken: 'saved-access-token',
        refreshToken: 'saved-refresh-token',
      );

      final loginOptions = RequestOptions(path: '/api/v1/auth/login');
      final handler1 = RequestInterceptorHandler();
      await interceptor.onRequest(loginOptions, handler1);
      expect(loginOptions.headers['Authorization'], isNull);

      final registerOptions = RequestOptions(path: '/api/v1/auth/register');
      final handler2 = RequestInterceptorHandler();
      await interceptor.onRequest(registerOptions, handler2);
      expect(registerOptions.headers['Authorization'], isNull);
    });

    test('does not retry if request was already retried once (prevents infinite loops)', () async {
      final options = RequestOptions(
        path: '/api/v1/tracks',
        extra: {'retried': true},
      );
      final error = DioException(
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: 401,
        ),
      );

      final handler = TestErrorHandler();
      await interceptor.onError(error, handler);
      expect(handler.passedError, equals(error));
      expect(handler.resolvedResponse, isNull);
    });
  });
}

class TestErrorHandler extends ErrorInterceptorHandler {
  DioException? passedError;
  Response? resolvedResponse;

  @override
  void next(DioException err) {
    passedError = err;
  }

  @override
  void resolve(Response response) {
    resolvedResponse = response;
  }
}
