import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hums_mobile/features/notifications/domain/entities/notification_item.dart';
import 'package:hums_mobile/features/notifications/domain/entities/notification_preferences.dart';
import 'package:hums_mobile/features/notifications/domain/repositories/notification_repository.dart';
import 'package:hums_mobile/features/notifications/presentation/providers/notification_provider.dart';
import 'package:hums_mobile/features/notifications/presentation/screens/notification_screen.dart';
import 'package:hums_mobile/features/notifications/presentation/states/notification_state.dart';

class MockNotificationInboxNotifier extends StateNotifier<NotificationInboxState>
    with Mock
    implements NotificationInboxNotifier {
  MockNotificationInboxNotifier(super.state);
}

class MockNotificationRepository extends Mock implements NotificationRepository {}

void main() {
  final testDate = DateTime(2026, 9, 21, 12, 0, 0);

  final tNotification1 = NotificationItemEntity(
    id: 'n-1',
    type: 'UPLOAD_COMPLETE',
    title: 'Track Processing Ready',
    body: 'Midnight Echoes has finished transcoding.',
    isRead: false,
    createdAt: testDate,
  );

  final tNotification2 = NotificationItemEntity(
    id: 'n-2',
    type: 'PLAYLIST_UPDATE',
    title: 'Playlist Updated',
    body: 'New track added to Lo-Fi Chill.',
    isRead: true,
    readAt: testDate,
    createdAt: testDate,
  );

  Widget createWidgetUnderTest(NotificationInboxState state, [MockNotificationInboxNotifier? notifier]) {
    final mockNotifier = notifier ?? MockNotificationInboxNotifier(state);
    if (notifier == null) {
      when(() => mockNotifier.loadNotifications()).thenAnswer((_) async {});
      when(() => mockNotifier.refresh()).thenAnswer((_) async {});
    }

    final mockRepo = MockNotificationRepository();
    when(() => mockRepo.getPreferences()).thenAnswer(
      (_) async => const NotificationPreferencesEntity(),
    );

    return ProviderScope(
      overrides: [
        notificationRepositoryProvider.overrideWithValue(mockRepo),
        notificationInboxNotifierProvider.overrideWith((ref) => mockNotifier),
      ],
      child: const MaterialApp(
        home: NotificationScreen(),
      ),
    );
  }

  group('NotificationScreen Widget Tests', () {
    testWidgets('renders loading spinner when state is loading', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          const NotificationInboxState(status: NotificationStatus.loading),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders empty state when notifications list is empty', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          const NotificationInboxState(
            status: NotificationStatus.loaded,
            notifications: [],
            unreadCount: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No notifications yet'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
    });

    testWidgets('renders notification items when populated', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          NotificationInboxState(
            status: NotificationStatus.loaded,
            notifications: [tNotification1, tNotification2],
            unreadCount: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Track Processing Ready'), findsOneWidget);
      expect(find.text('Midnight Echoes has finished transcoding.'), findsOneWidget);
      expect(find.text('Playlist Updated'), findsOneWidget);
      expect(find.text('Read all'), findsOneWidget);
    });

    testWidgets('filters list to unread notifications when unread tab selected', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          NotificationInboxState(
            status: NotificationStatus.loaded,
            notifications: [tNotification1, tNotification2],
            unreadCount: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially both are visible
      expect(find.text('Track Processing Ready'), findsOneWidget);
      expect(find.text('Playlist Updated'), findsOneWidget);

      // Tap unread filter
      await tester.tap(find.text('Unread (1)'));
      await tester.pumpAndSettle();

      // Only unread item should remain visible
      expect(find.text('Track Processing Ready'), findsOneWidget);
      expect(find.text('Playlist Updated'), findsNothing);
    });

    testWidgets('calls markAllAsRead when Read all button is tapped', (tester) async {
      final mockNotifier = MockNotificationInboxNotifier(
        NotificationInboxState(
          status: NotificationStatus.loaded,
          notifications: [tNotification1],
          unreadCount: 1,
        ),
      );
      when(() => mockNotifier.loadNotifications()).thenAnswer((_) async {});
      when(() => mockNotifier.markAllAsRead()).thenAnswer((_) async {});

      await tester.pumpWidget(
        createWidgetUnderTest(
          mockNotifier.state,
          mockNotifier,
        ),
      );
      await tester.pumpAndSettle();

      final readAllFinder = find.text('Read all');
      expect(readAllFinder, findsOneWidget);

      await tester.tap(readAllFinder);
      await tester.pump();

      verify(() => mockNotifier.markAllAsRead()).called(1);
    });
  });
}
