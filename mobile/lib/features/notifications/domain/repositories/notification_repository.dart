import 'package:hums_mobile/features/notifications/domain/entities/notification_item.dart';
import 'package:hums_mobile/features/notifications/domain/entities/notification_preferences.dart';

abstract class NotificationRepository {
  /// Fetches paginated notifications for the user
  Future<List<NotificationItemEntity>> getNotifications({
    int skip = 0,
    int limit = 50,
    bool? isRead,
  });

  /// Fetches the count of unread notifications for badge presentation
  Future<int> getUnreadCount();

  /// Marks a specific notification as read
  Future<NotificationItemEntity> markAsRead(String notificationId);

  /// Marks all notifications as read in bulk
  Future<int> markAllAsRead();

  /// Retrieves user notification preferences
  Future<NotificationPreferencesEntity> getPreferences();

  /// Updates user notification preferences
  Future<NotificationPreferencesEntity> updatePreferences(
    NotificationPreferencesEntity preferences,
  );

  /// Registers or refreshes device push token on backend
  Future<void> registerDevice({
    required String token,
    required String platform,
    String? deviceName,
    String? appVersion,
  });

  /// Deactivates a device registration by token on logout
  Future<void> deactivateDeviceToken(String token);
}
