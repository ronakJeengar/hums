/// Application Environment and Endpoint Configuration
abstract class EnvConfig {
  static const String appName = 'Hums';
  static const String appVersion = '1.0.0';

  // Base API URL (configurable via --dart-define=API_BASE_URL=...)
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8001',
  );

  static const int connectTimeoutSeconds = 15;
  static const int receiveTimeoutSeconds = 15;
}
