import 'package:hums_mobile/core/network/api_client.dart';
import 'package:hums_mobile/core/network/api_endpoints.dart';
import 'package:hums_mobile/features/notifications/data/models/notification_model.dart';

abstract class NotificationRemoteDataSource {
  Future<NotificationListModel> getNotifications({
    int skip = 0,
    int limit = 50,
    bool? isRead,
  });

  Future<int> getUnreadCount();

  Future<NotificationItemModel> markAsRead(String notificationId);

  Future<int> markAllAsRead();

  Future<NotificationPreferencesModel> getPreferences();

  Future<NotificationPreferencesModel> updatePreferences(
    NotificationPreferencesModel preferences,
  );

  Future<void> registerDevice({
    required String token,
    required String platform,
    String? deviceName,
    String? appVersion,
  });

  Future<void> deactivateDeviceToken(String token);
}

class NotificationRemoteDataSourceImpl implements NotificationRemoteDataSource {
  final ApiClient _apiClient;

  const NotificationRemoteDataSourceImpl(this._apiClient);

  @override
  Future<NotificationListModel> getNotifications({
    int skip = 0,
    int limit = 50,
    bool? isRead,
  }) async {
    final queryParams = <String, dynamic>{
      'skip': skip,
      'limit': limit,
    };
    if (isRead != null) {
      queryParams['is_read'] = isRead;
    }

    final response = await _apiClient.get(
      ApiEndpoints.notifications,
      queryParameters: queryParams,
    );
    final json = response.data as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>;
    return NotificationListModel.fromJson(data);
  }

  @override
  Future<int> getUnreadCount() async {
    final response = await _apiClient.get(ApiEndpoints.notificationUnreadCount);
    final json = response.data as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>;
    return (data['unread_count'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<NotificationItemModel> markAsRead(String notificationId) async {
    final response = await _apiClient.patch(
      ApiEndpoints.notificationRead(notificationId),
    );
    final json = response.data as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>;
    return NotificationItemModel.fromJson(data);
  }

  @override
  Future<int> markAllAsRead() async {
    final response = await _apiClient.post(ApiEndpoints.notificationReadAll);
    final json = response.data as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>;
    return (data['marked_count'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<NotificationPreferencesModel> getPreferences() async {
    final response = await _apiClient.get(ApiEndpoints.notificationPreferences);
    final json = response.data as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>;
    return NotificationPreferencesModel.fromJson(data);
  }

  @override
  Future<NotificationPreferencesModel> updatePreferences(
    NotificationPreferencesModel preferences,
  ) async {
    final response = await _apiClient.put(
      ApiEndpoints.notificationPreferences,
      data: preferences.toJson(),
    );
    final json = response.data as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>;
    return NotificationPreferencesModel.fromJson(data);
  }

  @override
  Future<void> registerDevice({
    required String token,
    required String platform,
    String? deviceName,
    String? appVersion,
  }) async {
    final payload = <String, dynamic>{
      'token': token,
      'platform': platform,
    };
    if (deviceName != null) payload['device_name'] = deviceName;
    if (appVersion != null) payload['app_version'] = appVersion;

    await _apiClient.post(
      ApiEndpoints.notificationDevices,
      data: payload,
    );
  }

  @override
  Future<void> deactivateDeviceToken(String token) async {
    await _apiClient.delete(
      ApiEndpoints.notificationDevices,
      queryParameters: {'token': token},
    );
  }
}
