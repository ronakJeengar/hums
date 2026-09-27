import 'package:hums_mobile/features/history/domain/entities/listening_history_item_entity.dart';
import 'package:hums_mobile/features/history/domain/entities/playback_event_entity.dart';
import 'package:hums_mobile/features/history/domain/entities/playback_progress_entity.dart';

abstract class HistoryRepository {
  /// Retrieves paginated recently played tracks from user listening history.
  Future<List<ListeningHistoryItemEntity>> getListeningHistory({
    int skip = 0,
    int limit = 50,
  });

  /// Retrieves saved playback resume progress for a single track.
  Future<PlaybackProgressEntity?> getPlaybackProgress(String trackId);

  /// Retrieves saved playback progress for multiple tracks in batch.
  Future<Map<String, PlaybackProgressEntity>> getBatchPlaybackProgress(
    List<String> trackIds,
  );

  /// Checkpoints playback progress directly.
  Future<PlaybackProgressEntity> updatePlaybackProgress(
    String trackId, {
    required int positionMs,
    required int durationMs,
    bool? completed,
  });

  /// Records a single playback lifecycle event (auto-enqueues offline if network fails).
  Future<void> recordEvent(PlaybackEventEntity event);

  /// Records batched playback lifecycle events.
  Future<void> recordBatchEvents(List<PlaybackEventEntity> events);

  /// Removes a track from the user's active listening history.
  Future<void> deleteHistoryItem(String trackId);

  /// Clears the user's active listening history.
  Future<void> clearHistory();

  /// Synchronizes locally queued offline playback events to the backend.
  Future<int> syncOfflineEvents();

  /// Gets the count of pending offline events.
  Future<int> getPendingOfflineEventCount();
}
