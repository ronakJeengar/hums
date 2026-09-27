import 'package:hums_mobile/features/history/data/datasources/history_local_data_source.dart';
import 'package:hums_mobile/features/history/data/datasources/history_remote_data_source.dart';
import 'package:hums_mobile/features/history/data/models/playback_event_model.dart';
import 'package:hums_mobile/features/history/data/models/playback_progress_model.dart';
import 'package:hums_mobile/features/history/domain/entities/listening_history_item_entity.dart';
import 'package:hums_mobile/features/history/domain/entities/playback_event_entity.dart';
import 'package:hums_mobile/features/history/domain/entities/playback_progress_entity.dart';
import 'package:hums_mobile/features/history/domain/repositories/history_repository.dart';

class HistoryRepositoryImpl implements HistoryRepository {
  final HistoryRemoteDataSource _remoteDataSource;
  final HistoryLocalDataSource _localDataSource;
  final String Function() _getUserId;

  HistoryRepositoryImpl(
    this._remoteDataSource,
    this._localDataSource,
    this._getUserId,
  );

  String get _userId => _getUserId();

  @override
  Future<List<ListeningHistoryItemEntity>> getListeningHistory({
    int skip = 0,
    int limit = 50,
  }) async {
    final models = await _remoteDataSource.getHistory(skip: skip, limit: limit);
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<PlaybackProgressEntity?> getPlaybackProgress(String trackId) async {
    try {
      final remote = await _remoteDataSource.getProgress(trackId);
      if (remote != null) {
        if (_userId.isNotEmpty) {
          await _localDataSource.saveProgress(_userId, remote);
        }
        return remote.toEntity();
      }
    } catch (_) {
      // Network failure, fall back to local offline cache
    }

    if (_userId.isNotEmpty) {
      final local = await _localDataSource.getProgress(_userId, trackId);
      if (local != null) {
        return local.toEntity();
      }
    }
    return null;
  }

  @override
  Future<Map<String, PlaybackProgressEntity>> getBatchPlaybackProgress(
    List<String> trackIds,
  ) async {
    if (trackIds.isEmpty) return {};
    try {
      final remoteMap = await _remoteDataSource.getBatchProgress(trackIds);
      if (_userId.isNotEmpty) {
        for (final model in remoteMap.values) {
          await _localDataSource.saveProgress(_userId, model);
        }
      }
      return remoteMap.map((k, v) => MapEntry(k, v.toEntity()));
    } catch (_) {
      // Fall back to local
      final result = <String, PlaybackProgressEntity>{};
      if (_userId.isNotEmpty) {
        for (final tid in trackIds) {
          final cached = await _localDataSource.getProgress(_userId, tid);
          if (cached != null) {
            result[tid] = cached.toEntity();
          }
        }
      }
      return result;
    }
  }

  @override
  Future<PlaybackProgressEntity> updatePlaybackProgress(
    String trackId, {
    required int positionMs,
    required int durationMs,
    bool? completed,
  }) async {
    final localModel = PlaybackProgressModel(
      trackId: trackId,
      positionMs: positionMs,
      durationMs: durationMs,
      completed: completed ?? (durationMs > 0 && positionMs >= (durationMs * 0.95).toInt()),
      progressPercent: durationMs > 0 ? (positionMs / durationMs).clamp(0.0, 1.0) : 0.0,
      updatedAt: DateTime.now().toUtc(),
    );

    // Persist to local cache immediately
    if (_userId.isNotEmpty) {
      await _localDataSource.saveProgress(_userId, localModel);
    }

    try {
      final remote = await _remoteDataSource.updateProgress(
        trackId,
        positionMs: positionMs,
        durationMs: durationMs,
        completed: completed,
      );
      return remote.toEntity();
    } catch (_) {
      // If remote failed, return the locally persisted state
      return localModel.toEntity();
    }
  }

  @override
  Future<void> recordEvent(PlaybackEventEntity event) async {
    final model = PlaybackEventModel.fromEntity(event);

    // Also update local cached progress state
    if (_userId.isNotEmpty) {
      final isDone = event.eventType == 'COMPLETED' ||
          (event.durationMs > 0 && event.positionMs >= (event.durationMs * 0.95).toInt());
      final progressModel = PlaybackProgressModel(
        trackId: event.trackId,
        positionMs: event.positionMs,
        durationMs: event.durationMs,
        completed: isDone,
        progressPercent: event.durationMs > 0 ? (event.positionMs / event.durationMs).clamp(0.0, 1.0) : 0.0,
        updatedAt: event.playedAt,
      );
      await _localDataSource.saveProgress(_userId, progressModel);
    }

    try {
      await _remoteDataSource.recordEvent(model);
    } catch (_) {
      // Network failed or offline: enqueue to local offline event queue for later sync
      if (_userId.isNotEmpty) {
        await _localDataSource.enqueueEvents(_userId, [model]);
      }
    }
  }

  @override
  Future<void> recordBatchEvents(List<PlaybackEventEntity> events) async {
    if (events.isEmpty) return;
    final models = events.map((e) => PlaybackEventModel.fromEntity(e)).toList();

    try {
      await _remoteDataSource.recordBatchEvents(models);
    } catch (_) {
      if (_userId.isNotEmpty) {
        await _localDataSource.enqueueEvents(_userId, models);
      }
    }
  }

  @override
  Future<void> deleteHistoryItem(String trackId) async {
    try {
      await _remoteDataSource.deleteHistoryItem(trackId);
    } catch (_) {}
  }

  @override
  Future<void> clearHistory() async {
    try {
      await _remoteDataSource.clearHistory();
    } catch (_) {}
    if (_userId.isNotEmpty) {
      await _localDataSource.clearUserData(_userId);
    }
  }

  @override
  Future<int> syncOfflineEvents() async {
    if (_userId.isEmpty) return 0;

    final pending = await _localDataSource.getPendingEvents(_userId);
    if (pending.isEmpty) return 0;

    int syncedCount = 0;
    // Chunk into batches of up to 50
    const chunkSize = 50;
    for (int i = 0; i < pending.length; i += chunkSize) {
      final end = (i + chunkSize < pending.length) ? i + chunkSize : pending.length;
      final chunk = pending.sublist(i, end);

      try {
        await _remoteDataSource.recordBatchEvents(chunk);
        final syncedIds = chunk.map((e) => e.eventId).toList();
        await _localDataSource.removeEvents(_userId, syncedIds);
        syncedCount += chunk.length;
      } catch (e) {
        // If an unrecoverable server error occurs or still offline, stop this sync pass
        break;
      }
    }
    return syncedCount;
  }

  @override
  Future<int> getPendingOfflineEventCount() async {
    if (_userId.isEmpty) return 0;
    final pending = await _localDataSource.getPendingEvents(_userId);
    return pending.length;
  }
}
