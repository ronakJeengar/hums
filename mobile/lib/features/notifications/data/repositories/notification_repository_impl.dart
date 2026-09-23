import 'package:hums_mobile/features/notifications/data/datasources/notification_remote_data_source.dart';
import 'package:hums_mobile/features/notifications/data/models/notification_model.dart';
import 'package:hums_mobile/features/notifications/domain/entities/notification_item.dart';
import 'package:hums_mobile/features/notifications/domain/entities/notification_preferences.dart';
import 'package:hums_mobile/features/notifications/domain/repositories/notification_repository.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final NotificationRemoteDataSource _remoteDataSource;

  const NotificationRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<NotificationItemEntity>> getNotifications({
    int skip = 0,
    int limit = 50,
    bool? isRead,
  }) async {
    final listModel = await _remoteDataSource.getNotifications(
      skip: skip,
      limit: limit,
      isRead: isRead,
    );
    return listModel.items.map((i) => i.toEntity()).toList();
  }

  @override
  Future<int> getUnreadCount() async {
    return await _remoteDataSource.getUnreadCount();
  }

  @override
  Future<NotificationItemEntity> markAsRead(String notificationId) async {
    final model = await _remoteDataSource.markAsRead(notificationId);
    return model.toEntity();
  }

  @override
  Future<int> markAllAsRead() async {
    return await _remoteDataSource.markAllAsRead();
  }

  @override
  Future<NotificationPreferencesEntity> getPreferences() async {
    final model = await _remoteDataSource.getPreferences();
    return model.toEntity();
  }

  @override
  Future<NotificationPreferencesEntity> updatePreferences(
    NotificationPreferencesEntity preferences,
  ) async {
    final reqModel = NotificationPreferencesModel(
      pushEnabled: preferences.pushEnabled,
      newReleasesEnabled: preferences.newReleasesEnabled,
      playlistUpdatesEnabled: preferences.playlistUpdatesEnabled,
      recommendationsEnabled: preferences.recommendationsEnabled,
      processingUpdatesEnabled: preferences.processingUpdatesEnabled,
    );
    final model = await _remoteDataSource.updatePreferences(reqModel);
    return model.toEntity();
  }

  @override
  Future<void> registerDevice({
    required String token,
    required String platform,
    String? deviceName,
    String? appVersion,
  }) async {
    await _remoteDataSource.registerDevice(
      token: token,
      platform: platform,
      deviceName: deviceName,
      appVersion: appVersion,
    );
  }

  @override
  Future<void> deactivateDeviceToken(String token) async {
    await _remoteDataSource.deactivateDeviceToken(token);
  }
}
