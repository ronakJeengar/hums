import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hums_mobile/features/history/data/datasources/history_local_data_source.dart';
import 'package:hums_mobile/features/history/data/models/playback_event_model.dart';
import 'package:hums_mobile/features/history/data/models/playback_progress_model.dart';

void main() {
  late Directory tempDir;
  late FileStorageHistoryLocalDataSourceImpl dataSource;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('history_local_test_');
    dataSource = FileStorageHistoryLocalDataSourceImpl(baseDirectory: tempDir);
    await dataSource.init();
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('enqueues offline events and retrieves pending', () async {
    final now = DateTime.now().toUtc();
    final ev1 = PlaybackEventModel(
      eventId: 'ev-1',
      trackId: 'track-1',
      eventType: 'PLAY_STARTED',
      positionMs: 0,
      durationMs: 180000,
      playedAt: now,
    );
    final ev2 = PlaybackEventModel(
      eventId: 'ev-2',
      trackId: 'track-1',
      eventType: 'PROGRESS_CHECKPOINT',
      positionMs: 45000,
      durationMs: 180000,
      playedAt: now,
    );

    await dataSource.enqueueEvents('user-1', [ev1, ev2]);

    final pending = await dataSource.getPendingEvents('user-1');
    expect(pending.length, equals(2));
    expect(pending[0].eventId, equals('ev-1'));
    expect(pending[1].positionMs, equals(45000));
  });

  test('deduplicates events by eventId', () async {
    final now = DateTime.now().toUtc();
    final ev1 = PlaybackEventModel(
      eventId: 'ev-dup',
      trackId: 'track-1',
      eventType: 'PLAY_STARTED',
      positionMs: 0,
      durationMs: 180000,
      playedAt: now,
    );

    await dataSource.enqueueEvents('user-1', [ev1]);
    await dataSource.enqueueEvents('user-1', [ev1]); // duplicate

    final pending = await dataSource.getPendingEvents('user-1');
    expect(pending.length, equals(1));
  });

  test('removes events after sync', () async {
    final now = DateTime.now().toUtc();
    final ev1 = PlaybackEventModel(
      eventId: 'ev-1',
      trackId: 'track-1',
      eventType: 'PLAY_STARTED',
      positionMs: 0,
      durationMs: 180000,
      playedAt: now,
    );
    final ev2 = PlaybackEventModel(
      eventId: 'ev-2',
      trackId: 'track-1',
      eventType: 'COMPLETED',
      positionMs: 180000,
      durationMs: 180000,
      playedAt: now,
    );

    await dataSource.enqueueEvents('user-1', [ev1, ev2]);
    await dataSource.removeEvents('user-1', ['ev-1']);

    final remaining = await dataSource.getPendingEvents('user-1');
    expect(remaining.length, equals(1));
    expect(remaining.first.eventId, equals('ev-2'));
  });

  test('caches and retrieves track progress locally for offline resume', () async {
    final now = DateTime.now().toUtc();
    final progress = PlaybackProgressModel(
      trackId: 'track-100',
      positionMs: 50000,
      durationMs: 200000,
      completed: false,
      progressPercent: 0.25,
      updatedAt: now,
    );

    await dataSource.saveProgress('user-1', progress);

    final retrieved = await dataSource.getProgress('user-1', 'track-100');
    expect(retrieved, isNotNull);
    expect(retrieved!.trackId, equals('track-100'));
    expect(retrieved.positionMs, equals(50000));
    expect(retrieved.progressPercent, equals(0.25));
  });

  test('enforces strict multi-user isolation on disk', () async {
    final now = DateTime.now().toUtc();
    final evUser1 = PlaybackEventModel(
      eventId: 'ev-u1',
      trackId: 'track-1',
      eventType: 'PLAY_STARTED',
      positionMs: 0,
      durationMs: 100000,
      playedAt: now,
    );
    final evUser2 = PlaybackEventModel(
      eventId: 'ev-u2',
      trackId: 'track-2',
      eventType: 'PLAY_STARTED',
      positionMs: 0,
      durationMs: 100000,
      playedAt: now,
    );

    await dataSource.enqueueEvents('user-1', [evUser1]);
    await dataSource.enqueueEvents('user-2', [evUser2]);

    final u1Events = await dataSource.getPendingEvents('user-1');
    final u2Events = await dataSource.getPendingEvents('user-2');

    expect(u1Events.map((e) => e.eventId), contains('ev-u1'));
    expect(u1Events.map((e) => e.eventId), isNot(contains('ev-u2')));

    expect(u2Events.map((e) => e.eventId), contains('ev-u2'));
    expect(u2Events.map((e) => e.eventId), isNot(contains('ev-u1')));
  });
}
