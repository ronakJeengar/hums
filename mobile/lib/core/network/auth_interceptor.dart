import 'dart:async';
import 'package:dio/dio.dart';
import 'package:hums_mobile/core/config/env_config.dart';
import 'package:hums_mobile/core/network/api_endpoints.dart';
import 'package:hums_mobile/features/auth/data/datasources/auth_local_data_source.dart';

class AuthInterceptor extends QueuedInterceptor {
  final AuthLocalDataSource _localDataSource;
  final Dio _refreshDio;
  Completer<String?>? _refreshCompleter;

  AuthInterceptor(this._localDataSource)
      : _refreshDio = Dio(
          BaseOptions(
            baseUrl: EnvConfig.apiBaseUrl,
            connectTimeout: const Duration(seconds: EnvConfig.connectTimeoutSeconds),
            receiveTimeout: const Duration(seconds: EnvConfig.receiveTimeoutSeconds),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        );

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Avoid adding bearer token to auth endpoints where it's not needed
    if (!_isAuthBypassEndpoint(options.path)) {
      final token = await _localDataSource.getAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    return handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Only intercept 401 Unauthorized errors
    if (err.response?.statusCode != 401) {
      return handler.next(err);
    }

    // Do not attempt to refresh if the failed request is itself an auth endpoint
    if (_isAuthBypassEndpoint(err.requestOptions.path)) {
      return handler.next(err);
    }

    // Prevent infinite retry loops
    if (err.requestOptions.extra['retried'] == true) {
      return handler.next(err);
    }

    try {
      final newAccessToken = await _performTokenRefresh();

      if (newAccessToken != null && newAccessToken.isNotEmpty) {
        // Clone and retry original request with new token
        final retryOptions = err.requestOptions;
        retryOptions.extra['retried'] = true;
        retryOptions.headers['Authorization'] = 'Bearer $newAccessToken';

        final response = await _refreshDio.fetch(retryOptions);
        return handler.resolve(response);
      }
    } catch (_) {
      // Refresh failed, proceed with original error
    }

    return handler.next(err);
  }

  Future<String?> _performTokenRefresh() async {
    // If a refresh is already in flight, wait for its completion
    if (_refreshCompleter != null) {
      return await _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<String?>();

    try {
      final refreshToken = await _localDataSource.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        await _localDataSource.clearAuth();
        _refreshCompleter!.complete(null);
        return null;
      }

      final response = await _refreshDio.post(
        ApiEndpoints.refresh,
        data: {'refresh_token': refreshToken},
      );

      final data = response.data as Map<String, dynamic>;
      final tokenData = data['data'] as Map<String, dynamic>;
      final newAccessToken = tokenData['access_token'] as String;
      final newRefreshToken = tokenData['refresh_token'] as String;

      await _localDataSource.saveTokens(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
      );

      _refreshCompleter!.complete(newAccessToken);
      return newAccessToken;
    } catch (e) {
      await _localDataSource.clearAuth();
      _refreshCompleter!.complete(null);
      return null;
    } finally {
      _refreshCompleter = null;
    }
  }

  bool _isAuthBypassEndpoint(String path) {
    return path == ApiEndpoints.login ||
        path == ApiEndpoints.register ||
        path == ApiEndpoints.refresh ||
        path == ApiEndpoints.forgotPassword ||
        path == ApiEndpoints.resetPassword;
  }
}
