import 'package:flutter_test/flutter_test.dart';
import 'package:hums_mobile/features/history/domain/entities/listening_history_item_entity.dart';
import 'package:hums_mobile/features/history/domain/entities/playback_event_entity.dart';
import 'package:hums_mobile/features/history/domain/entities/playback_progress_entity.dart';
import 'package:hums_mobile/features/history/domain/repositories/history_repository.dart';
import 'package:hums_mobile/features/history/presentation/providers/history_provider.dart';

class MockHistoryRepository implements HistoryRepository {
  List<ListeningHistoryItemEntity> historyItems = [];
  int offlineEventCount = 0;
  bool shouldThrow = false;

  @override
  Future<List<ListeningHistoryItemEntity>> getListeningHistory(
      {int skip = 0, int limit = 50}) async {
    if (shouldThrow) throw Exception('API failure');
    if (skip >= historyItems.length) return [];
    final end = (skip + limit < historyItems.length) ? skip + limit : historyItems.length;
    return historyItems.sublist(skip, end);
  }

  @override
  Future<PlaybackProgressEntity?> getPlaybackProgress(String trackId) async => null;

  @override
  Future<Map<String, PlaybackProgressEntity>> getBatchPlaybackProgress(
      List<String> trackIds) async => {};

  @override
  Future<PlaybackProgressEntity> updatePlaybackProgress(
    String trackId, {
    required int positionMs,
    required int durationMs,
    bool? completed,
  }) async {
    return PlaybackProgressEntity(
      trackId: trackId,
      positionMs: positionMs,
      durationMs: durationMs,
      completed: completed ?? false,
      progressPercent: 0.0,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> recordEvent(PlaybackEventEntity event) async {}

  @override
  Future<void> recordBatchEvents(List<PlaybackEventEntity> events) async {}

  @override
  Future<void> deleteHistoryItem(String trackId) async {
    historyItems.removeWhere((item) => item.trackId == trackId);
  }

  @override
  Future<void> clearHistory() async {
    historyItems.clear();
  }

  @override
  Future<int> syncOfflineEvents() async {
    final count = offlineEventCount;
    offlineEventCount = 0;
    return count;
  }

  @override
  Future<int> getPendingOfflineEventCount() async => offlineEventCount;
}

void main() {
  late MockHistoryRepository mockRepo;
  late ListeningHistoryNotifier notifier;

  setUp(() {
    mockRepo = MockHistoryRepository();
    notifier = ListeningHistoryNotifier(mockRepo);
  });

  test('loadHistory populates items and total', () async {
    final now = DateTime.now();
    mockRepo.historyItems = [
      ListeningHistoryItemEntity(
        id: 'h1',
        trackId: 't1',
        positionMs: 30000,
        durationMs: 180000,
        completed: false,
        progressPercent: 0.166,
        lastPlayedAt: now,
      ),
      ListeningHistoryItemEntity(
        id: 'h2',
        trackId: 't2',
        positionMs: 120000,
        durationMs: 120000,
        completed: true,
        progressPercent: 1.0,
        lastPlayedAt: now,
      ),
    ];

    await notifier.loadHistory();

    expect(notifier.state.isLoading, isFalse);
    expect(notifier.state.items.length, equals(2));
    expect(notifier.state.total, equals(2));
  });

  test('deleteItem updates state immediately and deletes from repository', () async {
    mockRepo.historyItems = [
      ListeningHistoryItemEntity(
        id: 'h1',
        trackId: 't1',
        positionMs: 30000,
        durationMs: 180000,
        completed: false,
        progressPercent: 0.166,
        lastPlayedAt: DateTime.now(),
      ),
    ];

    await notifier.loadHistory();
    expect(notifier.state.items.length, equals(1));

    await notifier.deleteItem('t1');
    expect(notifier.state.items.isEmpty, isTrue);
    expect(mockRepo.historyItems.isEmpty, isTrue);
  });

  test('clearAll removes all items', () async {
    mockRepo.historyItems = [
      ListeningHistoryItemEntity(
        id: 'h1',
        trackId: 't1',
        positionMs: 0,
        durationMs: 100,
        completed: false,
        progressPercent: 0.0,
        lastPlayedAt: DateTime.now(),
      ),
    ];

    await notifier.loadHistory();
    expect(notifier.state.items.isNotEmpty, isTrue);

    await notifier.clearAll();
    expect(notifier.state.items.isEmpty, isTrue);
    expect(notifier.state.total, equals(0));
  });

  test('syncOfflineQueue flushes pending offline events and updates badge', () async {
    mockRepo.offlineEventCount = 4;
    mockRepo.historyItems = [];

    await notifier.loadHistory();
    expect(notifier.state.pendingOfflineEventsCount, equals(4));

    await notifier.syncOfflineQueue();
    expect(notifier.state.pendingOfflineEventsCount, equals(0));
  });
}
