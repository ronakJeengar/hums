import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hums_mobile/features/history/data/datasources/history_local_data_source.dart';
import 'package:hums_mobile/features/history/data/datasources/history_remote_data_source.dart';
import 'package:hums_mobile/features/history/data/models/listening_history_model.dart';
import 'package:hums_mobile/features/history/data/models/playback_event_model.dart';
import 'package:hums_mobile/features/history/data/models/playback_progress_model.dart';
import 'package:hums_mobile/features/history/data/repositories/history_repository_impl.dart';
import 'package:hums_mobile/features/history/domain/entities/playback_event_entity.dart';

class FakeHistoryRemoteDataSource implements HistoryRemoteDataSource {
  bool shouldFail = false;
  final List<PlaybackEventModel> recordedEvents = [];
  final List<PlaybackEventModel> batchRecordedEvents = [];
  final Map<String, PlaybackProgressModel> progressStore = {};
  final List<ListeningHistoryItemModel> historyList = [];

  @override
  Future<void> recordEvent(PlaybackEventModel event) async {
    if (shouldFail) throw Exception('Network offline');
    recordedEvents.add(event);
  }

  @override
  Future<void> recordBatchEvents(List<PlaybackEventModel> events) async {
    if (shouldFail) throw Exception('Network offline');
    batchRecordedEvents.addAll(events);
  }

  @override
  Future<PlaybackProgressModel?> getProgress(String trackId) async {
    if (shouldFail) throw Exception('Network offline');
    return progressStore[trackId];
  }

  @override
  Future<Map<String, PlaybackProgressModel>> getBatchProgress(
      List<String> trackIds) async {
    if (shouldFail) throw Exception('Network offline');
    return {for (var id in trackIds) if (progressStore.containsKey(id)) id: progressStore[id]!};
  }

  @override
  Future<PlaybackProgressModel> updateProgress(
    String trackId, {
    required int positionMs,
    required int durationMs,
    bool? completed,
  }) async {
    if (shouldFail) throw Exception('Network offline');
    final model = PlaybackProgressModel(
      trackId: trackId,
      positionMs: positionMs,
      durationMs: durationMs,
      completed: completed ?? (positionMs >= durationMs * 0.95),
      progressPercent: durationMs > 0 ? (positionMs / durationMs).clamp(0.0, 1.0) : 0.0,
      updatedAt: DateTime.now().toUtc(),
    );
    progressStore[trackId] = model;
    return model;
  }

  @override
  Future<List<ListeningHistoryItemModel>> getHistory(
      {int skip = 0, int limit = 50}) async {
    if (shouldFail) throw Exception('Network offline');
    return historyList;
  }

  @override
  Future<void> deleteHistoryItem(String trackId) async {
    if (shouldFail) throw Exception('Network offline');
    historyList.removeWhere((item) => item.trackId == trackId);
  }

  @override
  Future<void> clearHistory() async {
    if (shouldFail) throw Exception('Network offline');
    historyList.clear();
  }
}

void main() {
  late Directory tempDir;
  late FileStorageHistoryLocalDataSourceImpl localDataSource;
  late FakeHistoryRemoteDataSource remoteDataSource;
  late HistoryRepositoryImpl repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('history_repo_test_');
    localDataSource = FileStorageHistoryLocalDataSourceImpl(baseDirectory: tempDir);
    await localDataSource.init();
    remoteDataSource = FakeHistoryRemoteDataSource();
    repository = HistoryRepositoryImpl(
      remoteDataSource,
      localDataSource,
      () => 'test-user-123',
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('online event recording sends to remote and does not queue offline', () async {
    final event = PlaybackEventEntity(
      eventId: 'ev-online',
      trackId: 'track-1',
      eventType: 'PLAY_STARTED',
      positionMs: 0,
      durationMs: 180000,
      playedAt: DateTime.now().toUtc(),
    );

    await repository.recordEvent(event);

    expect(remoteDataSource.recordedEvents.length, equals(1));
    expect(remoteDataSource.recordedEvents.first.eventId, equals('ev-online'));

    final pending = await repository.getPendingOfflineEventCount();
    expect(pending, equals(0));
  });

  test('offline / network error enqueues event into local offline queue', () async {
    remoteDataSource.shouldFail = true;

    final event = PlaybackEventEntity(
      eventId: 'ev-offline-1',
      trackId: 'track-1',
      eventType: 'PROGRESS_CHECKPOINT',
      positionMs: 60000,
      durationMs: 180000,
      playedAt: DateTime.now().toUtc(),
    );

    await repository.recordEvent(event);

    expect(remoteDataSource.recordedEvents.isEmpty, isTrue);

    final pending = await repository.getPendingOfflineEventCount();
    expect(pending, equals(1));
  });

  test('syncOfflineEvents flushes pending offline queue to remote in batches', () async {
    remoteDataSource.shouldFail = true;

    // Enqueue 3 events while offline
    for (int i = 1; i <= 3; i++) {
      await repository.recordEvent(
        PlaybackEventEntity(
          eventId: 'offline-$i',
          trackId: 'track-$i',
          eventType: 'PLAY_STARTED',
          positionMs: 0,
          durationMs: 100000,
          playedAt: DateTime.now().toUtc(),
        ),
      );
    }

    expect(await repository.getPendingOfflineEventCount(), equals(3));

    // Connectivity returns
    remoteDataSource.shouldFail = false;

    final syncedCount = await repository.syncOfflineEvents();
    expect(syncedCount, equals(3));
    expect(remoteDataSource.batchRecordedEvents.length, equals(3));

    // Queue is cleared
    expect(await repository.getPendingOfflineEventCount(), equals(0));
  });

  test('progress falls back to locally cached progress when offline', () async {
    // 1. While online, update progress
    await repository.updatePlaybackProgress(
      'track-resilient',
      positionMs: 45000,
      durationMs: 180000,
    );

    // 2. Go offline
    remoteDataSource.shouldFail = true;

    // 3. Retrieval should still return cached progress
    final retrieved = await repository.getPlaybackProgress('track-resilient');
    expect(retrieved, isNotNull);
    expect(retrieved!.trackId, equals('track-resilient'));
    expect(retrieved.positionMs, equals(45000));
  });
}
