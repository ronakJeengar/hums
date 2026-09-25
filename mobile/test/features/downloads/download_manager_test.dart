import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hums_mobile/core/observability/telemetry_service.dart';
import 'package:hums_mobile/features/downloads/data/services/download_file_manager.dart';
import 'package:hums_mobile/features/downloads/domain/entities/download_item.dart';
import 'package:hums_mobile/features/downloads/domain/entities/download_status.dart';
import 'package:hums_mobile/features/downloads/domain/repositories/download_repository.dart';
import 'package:hums_mobile/features/downloads/presentation/providers/download_manager_provider.dart';

class MockDownloadRepository extends Mock implements DownloadRepository {}
class MockDownloadFileManager extends Mock implements DownloadFileManager {}
class MockDio extends Mock implements Dio {}
class MockTelemetryService extends Mock implements TelemetryService {}

void main() {
  late MockDownloadRepository mockRepo;
  late MockDownloadFileManager mockFileManager;
  late MockTelemetryService mockTelemetry;
  late MockDio mockDio;
  late DownloadManager manager;

  final now = DateTime.now();

  setUpAll(() {
    registerFallbackValue(
      DownloadItem(
        id: 'fallback',
        trackId: 'fallback',
        userId: 'fallback',
        title: 'fallback',
        status: DownloadStatus.queued,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  });

  setUp(() async {
    mockRepo = MockDownloadRepository();
    mockFileManager = MockDownloadFileManager();
    mockTelemetry = MockTelemetryService();
    mockDio = MockDio();

    when(() => mockRepo.runStartupCleanup(any())).thenAnswer((_) async {});
    when(() => mockRepo.getDownloadsByUser(any())).thenAnswer((_) async => []);
    when(() => mockFileManager.calculateUserStorageUsage(any())).thenAnswer((_) async => 0);
    when(() => mockFileManager.cleanupOrphanFiles()).thenAnswer((_) async {});
    when(() => mockRepo.saveDownload(any())).thenAnswer((_) async {});
    when(() => mockRepo.updateDownload(any())).thenAnswer((_) async {});
    when(() => mockRepo.removeDownload(any(), any())).thenAnswer((_) async {});
    when(() => mockFileManager.deletePartialFile(any(), any())).thenAnswer((_) async {});
    when(() => mockFileManager.deleteTrackFiles(any(), any())).thenAnswer((_) async {});
    when(() => mockFileManager.isFinalFileValid(any())).thenAnswer((_) async => false);

    manager = DownloadManager(
      repository: mockRepo,
      fileManager: mockFileManager,
      telemetry: mockTelemetry,
      downloadDio: mockDio,
      maxConcurrentDownloads: 2,
    );
    await manager.init('user_1');
  });

  group('DownloadManager', () {
    test('initializes and loads user downloads from repository', () async {
      final existingItem = DownloadItem(
        id: 'dl_1',
        trackId: 'track_1',
        userId: 'user_1',
        title: 'Existing Download',
        status: DownloadStatus.completed,
        localPath: '/downloads/user_1/track_1/audio.m4a',
        createdAt: now,
        updatedAt: now,
      );

      when(() => mockRepo.getDownloadsByUser('user_1'))
          .thenAnswer((_) async => [existingItem]);
      when(() => mockFileManager.calculateUserStorageUsage('user_1'))
          .thenAnswer((_) async => 5000000);

      await manager.init('user_1');

      expect(manager.state.items.length, 1);
      expect(manager.state.items['track_1']?.title, 'Existing Download');
      expect(manager.state.totalStorageBytes, 5000000);
      expect(manager.state.isDownloaded('track_1'), isTrue);
    });

    test('enqueues a track and respects maximum concurrent limit', () async {
      final authItem1 = DownloadItem(
        id: 'dl_t1',
        trackId: 'track_1',
        userId: 'user_1',
        title: 'Track One',
        status: DownloadStatus.queued,
        downloadUrl: 'https://cdn.hums.app/d1.m4a',
        urlExpiresAt: now.add(const Duration(minutes: 15)),
        createdAt: now,
        updatedAt: now,
      );

      final authItem2 = authItem1.copyWith(
        id: 'dl_t2',
        trackId: 'track_2',
        title: 'Track Two',
      );

      final authItem3 = authItem1.copyWith(
        id: 'dl_t3',
        trackId: 'track_3',
        title: 'Track Three',
      );

      when(() => mockRepo.getAuthorizedDownload('track_1', 'user_1'))
          .thenAnswer((_) async => authItem1);
      when(() => mockRepo.getAuthorizedDownload('track_2', 'user_1'))
          .thenAnswer((_) async => authItem2);
      when(() => mockRepo.getAuthorizedDownload('track_3', 'user_1'))
          .thenAnswer((_) async => authItem3);

      // Make mockDio return an open stream that doesn't immediately close
      final completer1 = Completer<Response<ResponseBody>>();
      when(() => mockDio.get<ResponseBody>(any(), options: any(named: 'options'), cancelToken: any(named: 'cancelToken')))
          .thenAnswer((_) => completer1.future);

      final tempDir = await Directory.systemTemp.createTemp('dl_mgr_test_');
      final tempPart = File('${tempDir.path}/audio.part');
      await tempPart.writeAsBytes([]);

      when(() => mockFileManager.getPartialFile(any(), any()))
          .thenAnswer((_) async => tempPart);
      when(() => mockFileManager.getPartialFileLength(any(), any()))
          .thenAnswer((_) async => 0);

      await manager.enqueueDownload(trackId: 'track_1', title: 'Track One');
      await manager.enqueueDownload(trackId: 'track_2', title: 'Track Two');
      await manager.enqueueDownload(trackId: 'track_3', title: 'Track Three');

      expect(manager.state.items.length, 3);
      // With maxConcurrent = 2, first two should be downloading and 3rd queued
      final downloadingCount = manager.state.items.values
          .where((i) => i.status == DownloadStatus.downloading)
          .length;
      final queuedCount = manager.state.items.values
          .where((i) => i.status == DownloadStatus.queued)
          .length;

      expect(downloadingCount, 2);
      expect(queuedCount, 1);

      await tempDir.delete(recursive: true);
    });

    test('pauses and resumes download', () async {
      final item = DownloadItem(
        id: 'dl_p1',
        trackId: 'track_pause',
        userId: 'user_1',
        title: 'Pausable Track',
        status: DownloadStatus.downloading,
        progress: 0.4,
        createdAt: now,
        updatedAt: now,
      );

      when(() => mockRepo.getDownloadsByUser('user_1'))
          .thenAnswer((_) async => [item]);

      await manager.init('user_1');
      expect(manager.state.items['track_pause']?.status, DownloadStatus.downloading);

      await manager.pauseDownload('track_pause');
      expect(manager.state.items['track_pause']?.status, DownloadStatus.paused);
      verify(() => mockRepo.updateDownload(any(that: predicate<DownloadItem>((i) => i.status == DownloadStatus.paused)))).called(1);

      await manager.resumeDownload('track_pause');
      expect(manager.state.items['track_pause']?.status, DownloadStatus.queued);
    });

    test('cancels download and deletes partial file', () async {
      final item = DownloadItem(
        id: 'dl_c1',
        trackId: 'track_cancel',
        userId: 'user_1',
        title: 'Cancelable Track',
        status: DownloadStatus.downloading,
        createdAt: now,
        updatedAt: now,
      );

      when(() => mockRepo.getDownloadsByUser('user_1'))
          .thenAnswer((_) async => [item]);

      await manager.init('user_1');
      await manager.cancelDownload('track_cancel');

      expect(manager.state.items['track_cancel']?.status, DownloadStatus.cancelled);
      verify(() => mockFileManager.deletePartialFile('user_1', 'track_cancel')).called(1);
    });

    test('removes download and purges from local DB and filesystem', () async {
      final item = DownloadItem(
        id: 'dl_r1',
        trackId: 'track_remove',
        userId: 'user_1',
        title: 'Removable Track',
        status: DownloadStatus.completed,
        createdAt: now,
        updatedAt: now,
      );

      when(() => mockRepo.getDownloadsByUser('user_1'))
          .thenAnswer((_) async => [item]);

      await manager.init('user_1');
      expect(manager.state.items.containsKey('track_remove'), isTrue);

      await manager.removeDownload('track_remove');
      expect(manager.state.items.containsKey('track_remove'), isFalse);
      verify(() => mockRepo.removeDownload('track_remove', 'user_1')).called(1);
    });
  });
}
