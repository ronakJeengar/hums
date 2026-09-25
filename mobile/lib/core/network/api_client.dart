import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hums_mobile/core/config/env_config.dart';
import 'package:hums_mobile/core/network/api_exception.dart';

import 'package:hums_mobile/core/network/auth_interceptor.dart';
import 'package:hums_mobile/core/network/logging_interceptor.dart';
import 'package:hums_mobile/features/auth/presentation/providers/auth_provider.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final localDataSource = ref.watch(authLocalDataSourceProvider);
  final dio = Dio(
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

  dio.interceptors.add(AuthInterceptor(localDataSource));
  dio.interceptors.add(LoggingInterceptor());

  return ApiClient(dio);
});

class ApiClient {
  final Dio _dio;

  ApiClient(this._dio) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException error, ErrorInterceptorHandler handler) {
          if (error.response?.data is Map<String, dynamic>) {
            final customException = ApiException.fromResponse(
              error.response!.data as Map<String, dynamic>,
              error.response?.statusCode,
            );
            return handler.reject(
              DioException(
                requestOptions: error.requestOptions,
                response: error.response,
                error: customException,
                type: error.type,
              ),
            );
          }
          if (error.type == DioExceptionType.connectionError ||
              error.type == DioExceptionType.connectionTimeout) {
            final host = error.requestOptions.uri.host;
            final port = error.requestOptions.uri.port;
            final customException = ApiException.network(
              'Unable to connect to Hums backend at $host:$port. Please verify the FastAPI server is running on port $port.',
            );
            return handler.reject(
              DioException(
                requestOptions: error.requestOptions,
                response: error.response,
                error: customException,
                type: error.type,
              ),
            );
          }
          return handler.next(error);
        },
      ),
    );
  }

  Dio get dio => _dio;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      if (e.error is ApiException) {
        throw e.error as ApiException;
      }
      throw ApiException.network(e.message ?? 'Network connection failed');
    }
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    ProgressCallback? onSendProgress,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        onSendProgress: onSendProgress,
      );
    } on DioException catch (e) {
      if (e.error is ApiException) {
        throw e.error as ApiException;
      }
      throw ApiException.network(e.message ?? 'Network connection failed');
    }
  }

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      if (e.error is ApiException) {
        throw e.error as ApiException;
      }
      throw ApiException.network(e.message ?? 'Network connection failed');
    }
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      if (e.error is ApiException) {
        throw e.error as ApiException;
      }
      throw ApiException.network(e.message ?? 'Network connection failed');
    }
  }
}
