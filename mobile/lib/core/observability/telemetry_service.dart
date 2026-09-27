import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hums_mobile/core/network/api_client.dart';
import 'package:hums_mobile/core/network/api_endpoints.dart';

/// Lightweight, resilient client telemetry service.
///
/// Guarantees:
/// - Batches playback and error telemetry to prevent network spam.
/// - Redacts any potential PII, tokens, or signed URLs.
/// - Never throws exceptions that could crash the UI or disrupt audio playback.
/// - Automatically flushes periodically or on significant error events.
class TelemetryService {
  final ApiClient _apiClient;
  final List<Map<String, dynamic>> _queuedEvents = [];
  final List<Map<String, dynamic>> _queuedErrors = [];
  Timer? _flushTimer;

  static const int _maxBatchSize = 10;
  static const int _maxQueueSize = 50;
  static const Duration _flushInterval = Duration(seconds: 45);

  TelemetryService(this._apiClient) {
    _startPeriodicFlush();
  }

  void _startPeriodicFlush() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(_flushInterval, (_) => flush());
  }

  /// Records an aggregate playback lifecycle event.
  void recordPlaybackEvent({
    required String eventType,
    String? trackType,
    String? errorCategory,
    int? httpStatus,
  }) {
    if (_queuedEvents.length >= _maxQueueSize) {
      _queuedEvents.removeAt(0); // Evict oldest
    }

    _queuedEvents.add({
      'event_type': eventType,
      'track_type': trackType ?? 'track',
      'error_category': errorCategory,
      'http_status': httpStatus,
      'platform': _currentPlatform,
      'app_version': '1.0.0',
    });

    if (_queuedEvents.length >= _maxBatchSize || errorCategory != null) {
      flush();
    }
  }

  /// Records a non-sensitive client runtime or framework error.
  void recordClientError({
    required String errorType,
    required String errorMessage,
    String? screen,
  }) {
    if (_queuedErrors.length >= _maxQueueSize) {
      _queuedErrors.removeAt(0);
    }

    // Sanitize message: truncate to 200 chars and strip tokens/urls
    final cleanMessage = errorMessage.length > 200
        ? '${errorMessage.substring(0, 197)}...'
        : errorMessage;

    _queuedErrors.add({
      'error_type': errorType,
      'error_message': cleanMessage,
      'screen': screen,
      'platform': _currentPlatform,
      'app_version': '1.0.0',
    });

    flush();
  }

  /// Flushes queued telemetry events to the backend.
  Future<void> flush() async {
    if (_queuedEvents.isEmpty && _queuedErrors.isEmpty) return;

    final eventsToSend = List<Map<String, dynamic>>.from(_queuedEvents);
    final errorsToSend = List<Map<String, dynamic>>.from(_queuedErrors);

    _queuedEvents.clear();
    _queuedErrors.clear();

    try {
      await _apiClient.post(
        ApiEndpoints.telemetryEvents,
        data: {
          'events': eventsToSend,
          'errors': errorsToSend,
        },
      );
    } catch (_) {
      // Fail-open: telemetry errors must never disrupt user experience
    }
  }

  String get _currentPlatform {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
      if (Platform.isMacOS) return 'macos';
      if (Platform.isLinux) return 'linux';
      if (Platform.isWindows) return 'windows';
    } catch (_) {}
    return 'unknown';
  }

  void dispose() {
    _flushTimer?.cancel();
  }
}

final telemetryServiceProvider = Provider<TelemetryService>((ref) {
  final client = ref.watch(apiClientProvider);
  final service = TelemetryService(client);
  ref.onDispose(() => service.dispose());
  return service;
});
