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
  static String audioTrackDownload(String trackId) => '/api/v1/audio/tracks/$trackId/download';
  static String audioTrackWaveform(String trackId) => '/api/v1/audio/tracks/$trackId/waveform';
  static String audioJobStatus(String jobId) => '/api/v1/audio/jobs/$jobId';

  // Playlist Endpoints
  static const String playlists = '/api/v1/playlists';
  static String playlistDetails(String playlistId) => '/api/v1/playlists/$playlistId';
  static String playlistCover(String playlistId) => '/api/v1/playlists/$playlistId/cover';
  static String playlistTracks(String playlistId) => '/api/v1/playlists/$playlistId/tracks';
  static String playlistTrack(String playlistId, String trackId) =>
      '/api/v1/playlists/$playlistId/tracks/$trackId';
  static String playlistTracksReorder(String playlistId) =>
      '/api/v1/playlists/$playlistId/tracks/reorder';

  // Notification Endpoints
  static const String notificationDevices = '/api/v1/notifications/devices';
  static String notificationDevice(String deviceId) => '/api/v1/notifications/devices/$deviceId';
  static const String notificationPreferences = '/api/v1/notifications/preferences';
  static const String notifications = '/api/v1/notifications';
  static const String notificationUnreadCount = '/api/v1/notifications/unread-count';
  static String notificationRead(String notificationId) => '/api/v1/notifications/$notificationId/read';
  static const String notificationReadAll = '/api/v1/notifications/read-all';

  // Recommendation Endpoints
  static const String recommendations = '/api/v1/recommendations';
  static const String recommendationsRefresh = '/api/v1/recommendations/refresh';

  // Search Endpoints
  static const String search = '/api/v1/search';
  static const String searchSuggestions = '/api/v1/search/suggestions';

  // Playback & History Endpoints
  static const String playbackHistory = '/api/v1/playback/history';
  static const String playbackEvents = '/api/v1/playback/events';
  static String playbackProgress(String trackId) => '/api/v1/playback/progress/$trackId';
  static String playbackBatchProgress(List<String> trackIds) =>
      '/api/v1/playback/progress?track_ids=${trackIds.join(',')}';
  static String playbackHistoryItem(String trackId) => '/api/v1/playback/history/$trackId';

  // Telemetry & Observability
  static const String telemetryEvents = '/api/v1/telemetry/events';

  // Creator & Social Endpoints
  static const String creators = '/api/v1/creators';
  static String creatorDetails(String creatorId) => '/api/v1/creators/$creatorId';
  static String creatorFollow(String creatorId) => '/api/v1/creators/$creatorId/follow';
  static String creatorFollowStatus(String creatorId) => '/api/v1/creators/$creatorId/follow-status';
  static String creatorFollowers(String creatorId, {int page = 1, int size = 20}) =>
      '/api/v1/creators/$creatorId/followers?page=$page&size=$size';
  static String userFollowing({int page = 1, int size = 20}) =>
      '/api/v1/users/me/following?page=$page&size=$size';

  // Likes & Personal Library Endpoints
  static String trackLike(String trackId) => '/api/v1/tracks/$trackId/like';
  static String trackLikeStatus(String trackId) => '/api/v1/tracks/$trackId/like-status';
  static const String library = '/api/v1/library';
  static String libraryLikedTracks({int page = 1, int size = 20}) =>
      '/api/v1/library/liked-tracks?page=$page&size=$size';
}
