import 'package:hums_mobile/features/notifications/domain/entities/notification_item.dart';
import 'package:hums_mobile/features/notifications/domain/entities/notification_preferences.dart';

enum NotificationStatus { initial, loading, loaded, error }

class NotificationInboxState {
  final NotificationStatus status;
  final List<NotificationItemEntity> notifications;
  final int unreadCount;
  final bool isRefreshing;
  final String? errorMessage;

  const NotificationInboxState({
    this.status = NotificationStatus.initial,
    this.notifications = const [],
    this.unreadCount = 0,
    this.isRefreshing = false,
    this.errorMessage,
  });

  bool get isLoading => status == NotificationStatus.loading;
  bool get isLoaded => status == NotificationStatus.loaded;
  bool get hasError => status == NotificationStatus.error;
  bool get isEmpty => isLoaded && notifications.isEmpty;

  NotificationInboxState copyWith({
    NotificationStatus? status,
    List<NotificationItemEntity>? notifications,
    int? unreadCount,
    bool? isRefreshing,
    String? errorMessage,
    bool clearError = false,
  }) {
    return NotificationInboxState(
      status: status ?? this.status,
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class NotificationPreferencesState {
  final NotificationStatus status;
  final NotificationPreferencesEntity preferences;
  final bool isSaving;
  final String? errorMessage;

  const NotificationPreferencesState({
    this.status = NotificationStatus.initial,
    this.preferences = const NotificationPreferencesEntity(),
    this.isSaving = false,
    this.errorMessage,
  });

  bool get isLoading => status == NotificationStatus.loading;

  NotificationPreferencesState copyWith({
    NotificationStatus? status,
    NotificationPreferencesEntity? preferences,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
  }) {
    return NotificationPreferencesState(
      status: status ?? this.status,
      preferences: preferences ?? this.preferences,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
