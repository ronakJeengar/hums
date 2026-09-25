import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hums_mobile/features/downloads/data/datasources/download_local_data_source.dart';
import 'package:hums_mobile/features/downloads/domain/entities/download_item.dart';
import 'package:hums_mobile/features/downloads/domain/entities/download_status.dart';

void main() {
  late Directory tempDir;
  late FileStorageDownloadLocalDataSourceImpl dataSource;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hums_dl_test_');
    dataSource = FileStorageDownloadLocalDataSourceImpl(baseDirectory: tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  final now = DateTime.now();

  final tItemUser1 = DownloadItem(
    id: 'dl_user1_track1',
    trackId: 'track_1',
    userId: 'user_1',
    title: 'Track 1',
    artistName: 'Artist 1',
    status: DownloadStatus.completed,
    localPath: '/mock/path/audio.m4a',
    createdAt: now,
    updatedAt: now,
  );

  final tItemUser2 = DownloadItem(
    id: 'dl_user2_track2',
    trackId: 'track_2',
    userId: 'user_2',
    title: 'Track 2',
    artistName: 'Artist 2',
    status: DownloadStatus.downloading,
    progress: 0.5,
    createdAt: now,
    updatedAt: now,
  );

  group('FileStorageDownloadLocalDataSourceImpl', () {
    test('saves and retrieves download item by trackId', () async {
      await dataSource.saveDownload(tItemUser1);

      final retrieved = await dataSource.getDownload('track_1');
      expect(retrieved, isNotNull);
      expect(retrieved!.id, tItemUser1.id);
      expect(retrieved.trackId, 'track_1');
      expect(retrieved.status, DownloadStatus.completed);
      expect(retrieved.localPath, '/mock/path/audio.m4a');
    });

    test('enforces strict multi-user account isolation', () async {
      await dataSource.saveDownload(tItemUser1);
      await dataSource.saveDownload(tItemUser2);

      final user1Downloads = await dataSource.getDownloadsByUser('user_1');
      final user2Downloads = await dataSource.getDownloadsByUser('user_2');

      expect(user1Downloads.length, 1);
      expect(user1Downloads.first.trackId, 'track_1');

      expect(user2Downloads.length, 1);
      expect(user2Downloads.first.trackId, 'track_2');

      // User 3 has no downloads
      final user3Downloads = await dataSource.getDownloadsByUser('user_3');
      expect(user3Downloads, isEmpty);
    });

    test('updates download item correctly', () async {
      await dataSource.saveDownload(tItemUser1);

      final updated = tItemUser1.copyWith(
        status: DownloadStatus.failed,
        error: 'Network timeout',
      );
      await dataSource.updateDownload(updated);

      final retrieved = await dataSource.getDownload('track_1');
      expect(retrieved!.status, DownloadStatus.failed);
      expect(retrieved.error, 'Network timeout');
    });

    test('deletes download item by trackId', () async {
      await dataSource.saveDownload(tItemUser1);
      expect(await dataSource.getDownload('track_1'), isNotNull);

      await dataSource.deleteDownload('track_1');
      expect(await dataSource.getDownload('track_1'), isNull);
    });

    test('persists state across separate data source instances (restarts)', () async {
      await dataSource.saveDownload(tItemUser1);

      // Create new instance pointing to same base directory
      final newDataSource = FileStorageDownloadLocalDataSourceImpl(baseDirectory: tempDir);
      final retrieved = await newDataSource.getDownload('track_1');

      expect(retrieved, isNotNull);
      expect(retrieved!.id, tItemUser1.id);
      expect(retrieved.title, 'Track 1');
    });
  });
}
