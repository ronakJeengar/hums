/// Centralized API Endpoint Definitions
abstract class ApiEndpoints {
  static const String rootHealth = '/health';
  static const String deepHealth = '/api/v1/health';

  // Future Authentication Endpoints
  static const String register = '/api/v1/auth/register';
  static const String login = '/api/v1/auth/login';
  static const String refresh = '/api/v1/auth/refresh';
  static const String logout = '/api/v1/auth/logout';
  static const String currentUser = '/api/v1/users/me';
}
