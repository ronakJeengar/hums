import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hums_mobile/core/network/api_client.dart';
import 'package:hums_mobile/core/network/api_exception.dart';
import 'package:hums_mobile/features/notifications/data/datasources/notification_remote_data_source.dart';
import 'package:hums_mobile/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:hums_mobile/features/notifications/domain/entities/notification_item.dart';
import 'package:hums_mobile/features/notifications/domain/entities/notification_preferences.dart';
import 'package:hums_mobile/features/notifications/domain/repositories/notification_repository.dart';
import 'package:hums_mobile/features/notifications/presentation/states/notification_state.dart';

final notificationRemoteDataSourceProvider =
    Provider<NotificationRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return NotificationRemoteDataSourceImpl(apiClient);
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final remoteDataSource = ref.watch(notificationRemoteDataSourceProvider);
  return NotificationRepositoryImpl(remoteDataSource);
});

// ---------------------------------------------------------------------------
// Notification Inbox Notifier
// ---------------------------------------------------------------------------

final notificationInboxNotifierProvider =
    StateNotifierProvider<NotificationInboxNotifier, NotificationInboxState>((ref) {
  final repository = ref.watch(notificationRepositoryProvider);
  return NotificationInboxNotifier(repository);
});

class NotificationInboxNotifier extends StateNotifier<NotificationInboxState> {
  final NotificationRepository _repository;

  NotificationInboxNotifier(this._repository)
      : super(const NotificationInboxState());

  Future<void> loadNotifications() async {
    state = state.copyWith(status: NotificationStatus.loading, clearError: true);
    try {
      final items = await _repository.getNotifications();
      final unread = await _repository.getUnreadCount();
      state = state.copyWith(
        status: NotificationStatus.loaded,
        notifications: items,
        unreadCount: unread,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        status: NotificationStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        status: NotificationStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(isRefreshing: true, clearError: true);
    try {
      final items = await _repository.getNotifications();
      final unread = await _repository.getUnreadCount();
      state = state.copyWith(
        status: NotificationStatus.loaded,
        notifications: items,
        unreadCount: unread,
        isRefreshing: false,
      );
    } catch (e) {
      state = state.copyWith(isRefreshing: false);
    }
  }

  Future<void> fetchUnreadCount() async {
    try {
      final unread = await _repository.getUnreadCount();
      state = state.copyWith(unreadCount: unread);
    } catch (_) {}
  }

  Future<void> markAsRead(String notificationId) async {
    // Optimistic local update
    final updatedList = state.notifications.map((item) {
      if (item.id == notificationId && !item.isRead) {
        return item.copyWith(isRead: true, readAt: DateTime.now());
      }
      return item;
    }).toList();

    final prevUnread = state.unreadCount;
    final newUnread = (prevUnread > 0) ? prevUnread - 1 : 0;
    state = state.copyWith(notifications: updatedList, unreadCount: newUnread);

    try {
      await _repository.markAsRead(notificationId);
    } catch (_) {
      // Revert if network call fails
      state = state.copyWith(unreadCount: prevUnread);
    }
  }

  Future<void> markAllAsRead() async {
    final updatedList = state.notifications
        .map((item) => item.copyWith(isRead: true, readAt: DateTime.now()))
        .toList();

    state = state.copyWith(notifications: updatedList, unreadCount: 0);

    try {
      await _repository.markAllAsRead();
    } catch (_) {
      await refresh();
    }
  }

  void addIncomingNotification(NotificationItemEntity notification) {
    state = state.copyWith(
      notifications: [notification, ...state.notifications],
      unreadCount: state.unreadCount + 1,
    );
  }
}

// Convenient unread count provider for badges
final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref.watch(notificationInboxNotifierProvider).unreadCount;
});

// ---------------------------------------------------------------------------
// Notification Preferences Notifier
// ---------------------------------------------------------------------------

final notificationPreferencesNotifierProvider = StateNotifierProvider<
    NotificationPreferencesNotifier, NotificationPreferencesState>((ref) {
  final repository = ref.watch(notificationRepositoryProvider);
  return NotificationPreferencesNotifier(repository);
});

class NotificationPreferencesNotifier
    extends StateNotifier<NotificationPreferencesState> {
  final NotificationRepository _repository;

  NotificationPreferencesNotifier(this._repository)
      : super(const NotificationPreferencesState());

  Future<void> loadPreferences() async {
    state = state.copyWith(
        status: NotificationStatus.loading, clearError: true);
    try {
      final prefs = await _repository.getPreferences();
      state = state.copyWith(
        status: NotificationStatus.loaded,
        preferences: prefs,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        status: NotificationStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        status: NotificationStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<bool> updatePreferences(NotificationPreferencesEntity updated) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final result = await _repository.updatePreferences(updated);
      state = state.copyWith(
        isSaving: false,
        preferences: result,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }
}
