import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hums_mobile/features/notifications/domain/entities/notification_item.dart';
import 'package:hums_mobile/features/notifications/domain/entities/notification_preferences.dart';
import 'package:hums_mobile/features/notifications/domain/repositories/notification_repository.dart';
import 'package:hums_mobile/features/notifications/presentation/providers/notification_provider.dart';
import 'package:hums_mobile/features/notifications/presentation/states/notification_state.dart';

class MockNotificationRepository extends Mock implements NotificationRepository {}

void main() {
  late MockNotificationRepository mockRepo;
  late NotificationInboxNotifier notifier;

  setUp(() {
    mockRepo = MockNotificationRepository();
    notifier = NotificationInboxNotifier(mockRepo);
  });

  setUpAll(() {
    registerFallbackValue(
      const NotificationPreferencesEntity(),
    );
  });

  final testDate = DateTime(2026, 9, 21, 12, 0, 0);

  final tNotification = NotificationItemEntity(
    id: 'n-1',
    type: 'UPLOAD_COMPLETE',
    title: 'Track Ready',
    body: 'Your track has finished processing!',
    isRead: false,
    createdAt: testDate,
  );

  group('NotificationInboxNotifier Tests', () {
    test('initial state has default values', () {
      expect(notifier.state.status, NotificationStatus.initial);
      expect(notifier.state.notifications, isEmpty);
      expect(notifier.state.unreadCount, 0);
    });

    test('loadNotifications sets loaded status and items', () async {
      when(() => mockRepo.getNotifications()).thenAnswer((_) async => [tNotification]);
      when(() => mockRepo.getUnreadCount()).thenAnswer((_) async => 1);

      await notifier.loadNotifications();

      expect(notifier.state.status, NotificationStatus.loaded);
      expect(notifier.state.notifications.length, 1);
      expect(notifier.state.unreadCount, 1);
    });

    test('markAsRead updates item optimistically and decrements unread count', () async {
      when(() => mockRepo.getNotifications()).thenAnswer((_) async => [tNotification]);
      when(() => mockRepo.getUnreadCount()).thenAnswer((_) async => 1);
      when(() => mockRepo.markAsRead('n-1')).thenAnswer(
        (_) async => tNotification.copyWith(isRead: true),
      );

      await notifier.loadNotifications();
      expect(notifier.state.unreadCount, 1);

      await notifier.markAsRead('n-1');

      expect(notifier.state.notifications.first.isRead, true);
      expect(notifier.state.unreadCount, 0);
    });

    test('markAllAsRead sets all items to read and unread count to 0', () async {
      final tNotification2 = tNotification.copyWith(id: 'n-2');
      when(() => mockRepo.getNotifications()).thenAnswer((_) async => [tNotification, tNotification2]);
      when(() => mockRepo.getUnreadCount()).thenAnswer((_) async => 2);
      when(() => mockRepo.markAllAsRead()).thenAnswer((_) async => 2);

      await notifier.loadNotifications();
      expect(notifier.state.unreadCount, 2);

      await notifier.markAllAsRead();

      expect(notifier.state.unreadCount, 0);
      expect(notifier.state.notifications.every((n) => n.isRead), true);
    });

    test('addIncomingNotification prepends item and increments unread count', () {
      final incoming = tNotification.copyWith(id: 'incoming-1', title: 'New incoming');

      notifier.addIncomingNotification(incoming);

      expect(notifier.state.notifications.length, 1);
      expect(notifier.state.notifications.first.id, 'incoming-1');
      expect(notifier.state.unreadCount, 1);
    });
  });

  group('NotificationPreferencesNotifier Tests', () {
    late NotificationPreferencesNotifier prefsNotifier;

    setUp(() {
      prefsNotifier = NotificationPreferencesNotifier(mockRepo);
    });

    test('loadPreferences fetches preferences from repository', () async {
      const tPrefs = NotificationPreferencesEntity(
        pushEnabled: true,
        newReleasesEnabled: false,
      );
      when(() => mockRepo.getPreferences()).thenAnswer((_) async => tPrefs);

      await prefsNotifier.loadPreferences();

      expect(prefsNotifier.state.status, NotificationStatus.loaded);
      expect(prefsNotifier.state.preferences.newReleasesEnabled, false);
    });

    test('updatePreferences updates state on success', () async {
      const tPrefs = NotificationPreferencesEntity(
        pushEnabled: false,
      );
      when(() => mockRepo.updatePreferences(any())).thenAnswer((_) async => tPrefs);

      final success = await prefsNotifier.updatePreferences(tPrefs);

      expect(success, true);
      expect(prefsNotifier.state.preferences.pushEnabled, false);
      expect(prefsNotifier.state.isSaving, false);
    });
  });
}
