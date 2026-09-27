import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hums_mobile/features/notifications/data/datasources/notification_remote_data_source.dart';
import 'package:hums_mobile/features/notifications/data/models/notification_model.dart';
import 'package:hums_mobile/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:hums_mobile/features/notifications/domain/entities/notification_preferences.dart';

class MockNotificationRemoteDataSource extends Mock
    implements NotificationRemoteDataSource {}

void main() {
  late MockNotificationRemoteDataSource mockRemote;
  late NotificationRepositoryImpl repository;

  setUp(() {
    mockRemote = MockNotificationRemoteDataSource();
    repository = NotificationRepositoryImpl(mockRemote);
  });

  setUpAll(() {
    registerFallbackValue(
      const NotificationPreferencesModel(
        pushEnabled: true,
        newReleasesEnabled: true,
        playlistUpdatesEnabled: true,
        recommendationsEnabled: true,
        processingUpdatesEnabled: true,
      ),
    );
  });

  final testDate = DateTime(2026, 9, 21, 12, 0, 0);

  final tNotificationModel = NotificationItemModel(
    id: 'notif-1',
    type: 'UPLOAD_COMPLETE',
    title: 'Track Ready',
    body: 'Your track has finished processing!',
    data: {'track_id': 'trk-1'},
    isRead: false,
    createdAt: testDate,
  );

  final tListModel = NotificationListModel(
    items: [tNotificationModel],
    total: 1,
    skip: 0,
    limit: 50,
  );

  final tPreferencesModel = const NotificationPreferencesModel(
    pushEnabled: true,
    newReleasesEnabled: true,
    playlistUpdatesEnabled: true,
    recommendationsEnabled: true,
    processingUpdatesEnabled: true,
  );

  group('NotificationRepositoryImpl Tests', () {
    test('getNotifications returns mapped NotificationItemEntity list', () async {
      when(() => mockRemote.getNotifications(skip: 0, limit: 50, isRead: null))
          .thenAnswer((_) async => tListModel);

      final result = await repository.getNotifications();

      expect(result.length, 1);
      expect(result.first.id, 'notif-1');
      expect(result.first.title, 'Track Ready');
      expect(result.first.type, 'UPLOAD_COMPLETE');
      expect(result.first.isRead, false);
      verify(() => mockRemote.getNotifications(skip: 0, limit: 50, isRead: null)).called(1);
    });

    test('getUnreadCount returns integer count from remote', () async {
      when(() => mockRemote.getUnreadCount()).thenAnswer((_) async => 5);

      final result = await repository.getUnreadCount();

      expect(result, 5);
      verify(() => mockRemote.getUnreadCount()).called(1);
    });

    test('markAsRead returns updated NotificationItemEntity', () async {
      final readModel = NotificationItemModel(
        id: 'notif-1',
        type: 'UPLOAD_COMPLETE',
        title: 'Track Ready',
        body: 'Your track has finished processing!',
        isRead: true,
        readAt: testDate,
        createdAt: testDate,
      );

      when(() => mockRemote.markAsRead('notif-1'))
          .thenAnswer((_) async => readModel);

      final result = await repository.markAsRead('notif-1');

      expect(result.isRead, true);
      verify(() => mockRemote.markAsRead('notif-1')).called(1);
    });

    test('markAllAsRead returns count of marked notifications', () async {
      when(() => mockRemote.markAllAsRead()).thenAnswer((_) async => 3);

      final result = await repository.markAllAsRead();

      expect(result, 3);
      verify(() => mockRemote.markAllAsRead()).called(1);
    });

    test('getPreferences returns domain entity', () async {
      when(() => mockRemote.getPreferences()).thenAnswer((_) async => tPreferencesModel);

      final result = await repository.getPreferences();

      expect(result.pushEnabled, true);
      expect(result.newReleasesEnabled, true);
      verify(() => mockRemote.getPreferences()).called(1);
    });

    test('updatePreferences serializes and returns updated entity', () async {
      when(() => mockRemote.updatePreferences(any()))
          .thenAnswer((_) async => tPreferencesModel);

      final result = await repository.updatePreferences(
        const NotificationPreferencesEntity(pushEnabled: false),
      );

      expect(result.pushEnabled, true);
      verify(() => mockRemote.updatePreferences(any())).called(1);
    });

    test('registerDevice forwards payload to remote', () async {
      when(() => mockRemote.registerDevice(
            token: any(named: 'token'),
            platform: any(named: 'platform'),
            deviceName: any(named: 'deviceName'),
            appVersion: any(named: 'appVersion'),
          )).thenAnswer((_) async {});

      await repository.registerDevice(
        token: 'fcm_123',
        platform: 'ANDROID',
        deviceName: 'Pixel',
      );

      verify(() => mockRemote.registerDevice(
            token: 'fcm_123',
            platform: 'ANDROID',
            deviceName: 'Pixel',
            appVersion: null,
          )).called(1);
    });

    test('deactivateDeviceToken calls remote datasource', () async {
      when(() => mockRemote.deactivateDeviceToken('fcm_123'))
          .thenAnswer((_) async {});

      await repository.deactivateDeviceToken('fcm_123');

      verify(() => mockRemote.deactivateDeviceToken('fcm_123')).called(1);
    });
  });
}
