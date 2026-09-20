/// Centralized API Endpoint Definitions
abstract class ApiEndpoints {
  static const String rootHealth = '/health';
  static const String deepHealth = '/api/v1/health';

  // Authentication Endpoints
  static const String register = '/api/v1/auth/register';
  static const String login = '/api/v1/auth/login';
  static const String refresh = '/api/v1/auth/refresh';
  static const String logout = '/api/v1/auth/logout';
  static const String currentUser = '/api/v1/auth/me';
  static const String forgotPassword = '/api/v1/auth/forgot-password';
  static const String resetPassword = '/api/v1/auth/reset-password';

  // Profile Endpoints
  static const String profile = '/api/v1/profile';
  static const String avatar = '/api/v1/profile/avatar';

  // Audio Endpoints
  static const String audioUpload = '/api/v1/audio/upload';
  static const String audioTracks = '/api/v1/audio/tracks';
  static String audioTrackDetails(String trackId) => '/api/v1/audio/tracks/$trackId';
  static String audioTrackStatus(String trackId) => '/api/v1/audio/tracks/$trackId/status';
  static String audioTrackPlayback(String trackId) => '/api/v1/audio/tracks/$trackId/playback';
  static String audioTrackWaveform(String trackId) => '/api/v1/audio/tracks/$trackId/waveform';
  static String audioJobStatus(String jobId) => '/api/v1/audio/jobs/$jobId';
}

