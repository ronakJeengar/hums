import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Application Environment and Endpoint Configuration
abstract class EnvConfig {
  static const String appName = 'Hums';
  static const String appVersion = '1.0.0';

  // Base API URL (configurable via --dart-define=API_BASE_URL=...)
  static const String _rawApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8001',
  );

  /// Resolves the base API URL dynamically.
  /// On Android emulators, `localhost` / `127.0.0.1` points to the emulator itself,
  /// whereas `10.0.2.2` routes to the host machine running the backend server.
  static String get apiBaseUrl {
    if (!kIsWeb && Platform.isAndroid) {
      return _rawApiBaseUrl
          .replaceAll('localhost', '10.0.2.2')
          .replaceAll('127.0.0.1', '10.0.2.2');
    }
    return _rawApiBaseUrl;
  }

  static const int connectTimeoutSeconds = 15;
  static const int receiveTimeoutSeconds = 15;
}
