import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Interceptor that logs all outgoing HTTP requests, responses, and errors.
///
/// Features:
/// - Request method, URL, query parameters, and headers
/// - Request execution duration in milliseconds
/// - Response status code and payload preview
/// - Automatic redaction of sensitive credentials (passwords, tokens, API keys)
/// - Truncation for large payloads to prevent log flooding
/// - Automatically bypassed in release mode to avoid logcat / syslog data leakage
class LoggingInterceptor extends Interceptor {
  static const String _startTimeKey = 'request_start_time';
  static const int _maxPayloadLogLength = 1000;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kReleaseMode) {
      super.onRequest(options, handler);
      return;
    }

    options.extra[_startTimeKey] = DateTime.now().millisecondsSinceEpoch;

    final method = options.method.toUpperCase();
    final uri = options.uri.toString();
    final sanitizedHeaders = _sanitizeHeaders(options.headers);
    final sanitizedData = _sanitizeData(options.data);

    final buffer = StringBuffer();
    buffer.writeln('--> $method $uri');

    if (options.queryParameters.isNotEmpty) {
      buffer.writeln('Query: ${options.queryParameters}');
    }

    if (sanitizedHeaders.isNotEmpty) {
      buffer.writeln('Headers: $sanitizedHeaders');
    }

    if (sanitizedData != null) {
      final bodyStr = sanitizedData.toString();
      buffer.writeln(
        'Body: ${bodyStr.length > _maxPayloadLogLength ? "${bodyStr.substring(0, _maxPayloadLogLength)}... [truncated]" : bodyStr}',
      );
    }

    developer.log(
      buffer.toString().trimRight(),
      name: 'HumsAPI',
    );

    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kReleaseMode) {
      super.onResponse(response, handler);
      return;
    }

    final startTime = response.requestOptions.extra[_startTimeKey] as int?;
    final durationMs = startTime != null
        ? DateTime.now().millisecondsSinceEpoch - startTime
        : null;

    final method = response.requestOptions.method.toUpperCase();
    final uri = response.requestOptions.uri.toString();
    final statusCode = response.statusCode;
    final durationStr = durationMs != null ? ' (${durationMs}ms)' : '';

    final buffer = StringBuffer();
    buffer.writeln('<-- $statusCode $method $uri$durationStr');

    if (response.data != null) {
      final sanitizedData = _sanitizeData(response.data);
      final bodyStr = sanitizedData.toString();
      buffer.writeln(
        'Response: ${bodyStr.length > _maxPayloadLogLength ? "${bodyStr.substring(0, _maxPayloadLogLength)}... [truncated]" : bodyStr}',
      );
    }

    developer.log(
      buffer.toString().trimRight(),
      name: 'HumsAPI',
    );

    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kReleaseMode) {
      super.onError(err, handler);
      return;
    }

    final startTime = err.requestOptions.extra[_startTimeKey] as int?;
    final durationMs = startTime != null
        ? DateTime.now().millisecondsSinceEpoch - startTime
        : null;

    final method = err.requestOptions.method.toUpperCase();
    final uri = err.requestOptions.uri.toString();
    final statusCode = err.response?.statusCode;
    final durationStr = durationMs != null ? ' (${durationMs}ms)' : '';

    final buffer = StringBuffer();
    buffer.writeln('<-- ERROR ${statusCode ?? 'NO_STATUS'} $method $uri$durationStr');
    buffer.writeln('Error Type: ${err.type}');
    buffer.writeln('Error Message: ${err.message}');

    if (err.response?.data != null) {
      final sanitizedData = _sanitizeData(err.response!.data);
      buffer.writeln('Error Body: $sanitizedData');
    }

    developer.log(
      buffer.toString().trimRight(),
      name: 'HumsAPI',
      error: err.error,
    );

    super.onError(err, handler);
  }

  Map<String, dynamic> _sanitizeHeaders(Map<String, dynamic> headers) {
    final sanitized = <String, dynamic>{};
    for (final entry in headers.entries) {
      final key = entry.key.toLowerCase();
      if (key == 'authorization' || key == 'cookie' || key == 'set-cookie') {
        sanitized[entry.key] = '[REDACTED]';
      } else {
        sanitized[entry.key] = entry.value;
      }
    }
    return sanitized;
  }

  dynamic _sanitizeData(dynamic data) {
    if (data == null) return null;

    if (data is Map) {
      final sanitized = <String, dynamic>{};
      for (final entry in data.entries) {
        final key = entry.key.toString();
        final lower = key.toLowerCase();
        if (lower.contains('password') ||
            lower.contains('token') ||
            lower.contains('secret') ||
            lower.contains('api_key') ||
            lower.contains('authorization')) {
          sanitized[key] = '[REDACTED]';
        } else if (entry.value is Map || entry.value is List) {
          sanitized[key] = _sanitizeData(entry.value);
        } else {
          sanitized[key] = entry.value;
        }
      }
      return sanitized;
    } else if (data is List) {
      return data.map(_sanitizeData).toList();
    } else if (data is FormData) {
      final fields = data.fields.map((f) {
        final lower = f.key.toLowerCase();
        if (lower.contains('password') || lower.contains('token')) {
          return '${f.key}: [REDACTED]';
        }
        return '${f.key}: ${f.value}';
      }).join(', ');
      final files = data.files
          .map((f) => '${f.key}: ${f.value.filename} (${f.value.length} bytes)')
          .join(', ');
      return 'FormData(fields: {$fields}, files: {$files})';
    }

    return data;
  }
}
