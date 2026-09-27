import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hums_mobile/core/network/api_client.dart';
import 'package:hums_mobile/core/utils/uuid_utils.dart';
import 'package:hums_mobile/features/audio_player/data/datasources/audio_player_remote_data_source.dart';
import 'package:hums_mobile/features/audio_player/data/services/audio_player_service.dart';
import 'package:hums_mobile/features/audio_player/data/repositories/audio_player_repository_impl.dart';
import 'package:hums_mobile/features/audio_player/domain/entities/player_error.dart';
import 'package:hums_mobile/features/audio_player/domain/entities/player_queue.dart';
import 'package:hums_mobile/features/audio_player/domain/repositories/audio_player_repository.dart';
import 'package:hums_mobile/features/audio_player/presentation/states/player_state.dart';
import 'package:hums_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:hums_mobile/features/auth/presentation/states/auth_state.dart';
import 'package:hums_mobile/features/downloads/presentation/providers/download_manager_provider.dart';
import 'package:hums_mobile/features/history/domain/entities/playback_event_entity.dart';
import 'package:hums_mobile/features/history/domain/repositories/history_repository.dart';
import 'package:hums_mobile/features/history/presentation/providers/history_provider.dart';

final audioPlayerRemoteDataSourceProvider =
    Provider<AudioPlayerRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AudioPlayerRemoteDataSourceImpl(apiClient);
});

final audioPlayerServiceProvider = Provider<AudioPlayerService>((ref) {
  final service = AudioPlayerService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

final audioPlayerRepositoryProvider = Provider<AudioPlayerRepository>((ref) {
  final remoteDataSource = ref.watch(audioPlayerRemoteDataSourceProvider);
  final service = ref.watch(audioPlayerServiceProvider);
  final downloadLocal = ref.watch(downloadLocalDataSourceProvider);
  return AudioPlayerRepositoryImpl(remoteDataSource, service, downloadLocal);
});

final audioPlayerNotifierProvider =
    StateNotifierProvider<AudioPlayerNotifier, PlayerState>((ref) {
  final repository = ref.watch(audioPlayerRepositoryProvider);
  final historyRepo = ref.watch(historyRepositoryProvider);
  final notifier = AudioPlayerNotifier(repository, historyRepo);

  // Clear queue and recommendations on logout to prevent cross-account leakage
  ref.listen<AuthState>(authNotifierProvider, (previous, next) {
    if (previous?.isAuthenticated == true && !next.isAuthenticated) {
      notifier.resetQueueOnLogout();
    }
  });

  return notifier;
});

class AudioPlayerNotifier extends StateNotifier<PlayerState> {
  final AudioPlayerRepository _repository;
  final HistoryRepository? _historyRepository;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<Duration>? _bufferedSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<bool>? _bufferingSub;
  StreamSubscription<bool>? _completedSub;

  Timer? _checkpointTimer;
  bool _isBuffering = false;
  bool _isPrefetching = false;

  AudioPlayerNotifier(
    this._repository, [
    this._historyRepository,
  ]) : super(const PlayerState()) {
    _initStreams();
  }

  void _initStreams() {
    _positionSub = _repository.positionStream.listen((position) {
      if (mounted) {
        state = state.copyWith(position: position);
      }
    });

    _durationSub = _repository.durationStream.listen((duration) {
      if (mounted && duration != null) {
        state = state.copyWith(duration: duration);
      }
    });

    _bufferedSub = _repository.bufferedPositionStream.listen((buffered) {
      if (mounted) {
        state = state.copyWith(bufferedPosition: buffered);
      }
    });

    _bufferingSub = _repository.isBufferingStream.listen((isBuffering) {
      _isBuffering = isBuffering;
      if (!mounted) return;
      if (state.isLoading || state.isError || state.isIdle) return;

      if (isBuffering) {
        state = state.copyWith(status: PlayerStatus.buffering);
      } else if (state.isBuffering) {
        state = state.copyWith(
          status: state.isPlaying ? PlayerStatus.playing : PlayerStatus.paused,
        );
      }
    });

    _playingSub = _repository.isPlayingStream.listen((isPlaying) {
      if (!mounted) return;
      if (state.isLoading || state.isError || state.isIdle) return;

      if (_isBuffering) {
        state = state.copyWith(status: PlayerStatus.buffering);
      } else if (isPlaying) {
        state = state.copyWith(status: PlayerStatus.playing);
        _startCheckpointTimer();
      } else {
        _stopCheckpointTimer();
        if (!state.isCompleted) {
          state = state.copyWith(status: PlayerStatus.paused);
        }
      }
    });

    _completedSub = _repository.isCompletedStream.listen((isCompleted) async {
      if (!mounted) return;
      if (isCompleted && !state.isIdle && !state.isLoading) {
        _stopCheckpointTimer();
        await _emitPlaybackEvent('COMPLETED', isCompleted: true);
        await _checkpointProgress(isCompleted: true);

        if (state.repeatMode == PlaybackRepeatMode.repeatTrack) {
          await seek(Duration.zero);
          await play();
        } else if (state.hasNext) {
          await skipToNext();
        } else {
          state = state.copyWith(status: PlayerStatus.completed);
        }
      }
    });
  }

  void _startCheckpointTimer() {
    _checkpointTimer?.cancel();
    _checkpointTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      if (state.isPlaying && state.track != null) {
        await _emitPlaybackEvent('PROGRESS_CHECKPOINT');
        await _checkpointProgress();
      }
    });
  }

  void _stopCheckpointTimer() {
    _checkpointTimer?.cancel();
    _checkpointTimer = null;
  }

  Future<void> _emitPlaybackEvent(
    String eventType, {
    int? customPositionMs,
    bool? isCompleted,
  }) async {
    if (_historyRepository == null || state.track == null) return;
    final posMs = customPositionMs ?? state.position.inMilliseconds;
    final durMs = state.duration.inMilliseconds > 0
        ? state.duration.inMilliseconds
        : ((state.track!.durationSeconds ?? 0) * 1000);

    final event = PlaybackEventEntity(
      eventId: UuidUtils.generate(),
      trackId: state.track!.trackId,
      eventType: eventType,
      positionMs: posMs,
      durationMs: durMs,
      playedAt: DateTime.now().toUtc(),
      source: 'player',
    );

    try {
      await _historyRepository.recordEvent(event);
    } catch (_) {}
  }

  Future<void> _checkpointProgress({bool? isCompleted}) async {
    if (_historyRepository == null || state.track == null) return;
    final posMs = state.position.inMilliseconds;
    final durMs = state.duration.inMilliseconds > 0
        ? state.duration.inMilliseconds
        : ((state.track!.durationSeconds ?? 0) * 1000);

    try {
      await _historyRepository.updatePlaybackProgress(
        state.track!.trackId,
        positionMs: posMs,
        durationMs: durMs,
        completed: isCompleted,
      );
    } catch (_) {}
  }

  /// Automatically prefetches smart queue candidates in the background
  /// when remaining upcoming items are running low (<= 2).
  Future<void> _prefetchSmartQueue() async {
    if (_isPrefetching) return;
    final trackId = state.track?.trackId;
    if (trackId == null) return;

    _isPrefetching = true;
    try {
      final currentQueue = state.queue;
      final excludeIds = <String>{
        trackId,
        if (currentQueue != null) ...[
          ...currentQueue.manualItems.map((i) => i.trackId),
          ...currentQueue.upNextItems.map((i) => i.trackId),
          ...currentQueue.smartItems.map((i) => i.trackId),
          ...currentQueue.historyItems.map((i) => i.trackId),
        ],
      }.toList();

      final candidates = await _repository.getUpNextCandidates(
        currentTrackId: trackId,
        limit: 10,
        excludeIds: excludeIds,
      );

      if (mounted && candidates.isNotEmpty && state.queue != null) {
        final existingTrackIds = {
          trackId,
          ...state.queue!.manualItems.map((i) => i.trackId),
          ...state.queue!.upNextItems.map((i) => i.trackId),
          ...state.queue!.smartItems.map((i) => i.trackId),
        };
        final newCandidates = candidates
            .where((c) => !existingTrackIds.contains(c.trackId))
            .toList();

        if (newCandidates.isNotEmpty) {
          state = state.copyWith(
            queue: state.queue!.copyWith(
              smartItems: [...state.queue!.smartItems, ...newCandidates],
            ),
          );
        }
      }
    } catch (_) {
      // Background prefetch fail should never disrupt playback
    } finally {
      _isPrefetching = false;
    }
  }

  Future<void> playTrack(String trackId) async {
    // If the same track is already loaded
    if (state.track?.trackId == trackId) {
      if (state.isPaused || state.isReady) {
        await resume();
        return;
      } else if (state.isCompleted) {
        await seek(Duration.zero);
        await resume();
        return;
      } else if (state.isPlaying) {
        return;
      }
    }

    // Checkpoint previous track if replacing an active track
    if (state.track != null && (state.isPlaying || state.isPaused)) {
      await _emitPlaybackEvent('STOPPED');
      await _checkpointProgress();
    }
    _stopCheckpointTimer();

    state = state.copyWith(
      status: PlayerStatus.loading,
      error: null,
      position: Duration.zero,
      duration: Duration.zero,
      bufferedPosition: Duration.zero,
    );

    try {
      final trackPlayback = await _repository.getPlaybackSource(trackId);
      final initialDuration = trackPlayback.durationSeconds != null
          ? Duration(seconds: trackPlayback.durationSeconds!)
          : Duration.zero;

      state = state.copyWith(
        track: trackPlayback,
        duration: initialDuration,
      );

      // Initialize single-track queue if no queue exists
      if (state.queue == null) {
        final item = QueueItem(
          trackId: trackPlayback.trackId,
          title: trackPlayback.title,
          artistName: trackPlayback.artistName,
          albumName: trackPlayback.albumName,
          durationSeconds: trackPlayback.durationSeconds,
          status: 'READY',
          source: QueueItemSource.search,
        );
        state = state.copyWith(
          queue: PlayerQueue(
            items: [item],
            currentIndex: 0,
            upNextItems: const [],
            manualItems: const [],
            smartItems: const [],
          ),
        );
      }

      // Check saved progress for cross-device resume & replay logic
      Duration resumePosition = Duration.zero;
      if (_historyRepository != null) {
        try {
          final savedProgress =
              await _historyRepository.getPlaybackProgress(trackId);
          if (savedProgress != null) {
            // If already completed (>95%), restart from 0:00 as required
            if (savedProgress.completed || savedProgress.progressPercent >= 0.95) {
              resumePosition = Duration.zero;
            } else if (savedProgress.positionMs > 3000 &&
                savedProgress.positionMs < (savedProgress.durationMs * 0.95)) {
              // Resume from where the user left off
              resumePosition = Duration(milliseconds: savedProgress.positionMs);
            }
          }
        } catch (_) {
          // Fail gracefully and start at 0
        }
      }

      await _repository.loadTrack(trackPlayback);
      if (resumePosition > Duration.zero) {
        await _repository.seek(resumePosition);
        state = state.copyWith(position: resumePosition);
      }

      await _repository.play();
      state = state.copyWith(status: PlayerStatus.playing);

      _startCheckpointTimer();
      await _emitPlaybackEvent(
        'PLAY_STARTED',
        customPositionMs: resumePosition.inMilliseconds,
      );

      // Trigger prefetch if upcoming items are low
      if (state.queue != null && state.queue!.upcomingCount <= 2) {
        unawaited(_prefetchSmartQueue());
      }
    } on PlayerError catch (e) {
      state = state.copyWith(
        status: PlayerStatus.error,
        error: e,
      );
    } catch (e) {
      state = state.copyWith(
        status: PlayerStatus.error,
        error: PlayerError(
          type: PlayerErrorType.unknown,
          message: e.toString(),
        ),
      );
    }
  }

  Future<void> togglePlayPause() async {
    if (state.isPlaying) {
      await pause();
    } else if (state.canPlay) {
      if (state.isCompleted) {
        await seek(Duration.zero);
      }
      await resume();
    }
  }

  Future<void> play() async {
    try {
      await _repository.play();
      _startCheckpointTimer();
      await _emitPlaybackEvent('RESUMED');
    } on PlayerError catch (e) {
      state = state.copyWith(status: PlayerStatus.error, error: e);
    } catch (e) {
      state = state.copyWith(
        status: PlayerStatus.error,
        error: PlayerError(type: PlayerErrorType.unknown, message: e.toString()),
      );
    }
  }

  Future<void> pause() async {
    try {
      _stopCheckpointTimer();
      await _repository.pause();
      await _emitPlaybackEvent('PAUSED');
      await _checkpointProgress();
    } on PlayerError catch (e) {
      state = state.copyWith(status: PlayerStatus.error, error: e);
    } catch (e) {
      state = state.copyWith(
        status: PlayerStatus.error,
        error: PlayerError(type: PlayerErrorType.unknown, message: e.toString()),
      );
    }
  }

  Future<void> resume() async {
    try {
      await _repository.resume();
      _startCheckpointTimer();
      await _emitPlaybackEvent('RESUMED');
    } on PlayerError catch (e) {
      state = state.copyWith(status: PlayerStatus.error, error: e);
    } catch (e) {
      state = state.copyWith(
        status: PlayerStatus.error,
        error: PlayerError(type: PlayerErrorType.unknown, message: e.toString()),
      );
    }
  }

  Future<void> seek(Duration position) async {
    try {
      await _repository.seek(position);
      state = state.copyWith(position: position);
      await _emitPlaybackEvent('SEEKED', customPositionMs: position.inMilliseconds);
      await _checkpointProgress();
    } on PlayerError catch (e) {
      state = state.copyWith(status: PlayerStatus.error, error: e);
    } catch (e) {
      state = state.copyWith(
        status: PlayerStatus.error,
        error: PlayerError(type: PlayerErrorType.unknown, message: e.toString()),
      );
    }
  }

  Future<void> seekRelative(Duration offset) async {
    final target = state.position + offset;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (state.duration > Duration.zero && target > state.duration
            ? state.duration
            : target);
    await seek(clamped);
  }

  Future<void> seekBackward10() async {
    await seekRelative(const Duration(seconds: -10));
  }

  Future<void> seekForward30() async {
    await seekRelative(const Duration(seconds: 30));
  }

  /// Starts playback for a given queue (playlist, album, or recommendations).
  Future<void> playQueue(PlayerQueue queue, {int startIndex = 0}) async {
    int targetIndex = startIndex;
    if (targetIndex < 0 || targetIndex >= queue.items.length) {
      targetIndex = 0;
    }

    // Find first playable track starting at targetIndex
    int? playableIndex;
    for (int i = targetIndex; i < queue.items.length; i++) {
      if (queue.items[i].isPlayable) {
        playableIndex = i;
        break;
      }
    }
    if (playableIndex == null) {
      for (int i = 0; i < targetIndex; i++) {
        if (queue.items[i].isPlayable) {
          playableIndex = i;
          break;
        }
      }
    }

    if (playableIndex == null) {
      state = state.copyWith(
        queue: queue,
        status: PlayerStatus.error,
        error: const PlayerError(
          type: PlayerErrorType.audioLoadFailed,
          message: 'No playable tracks available in this playlist',
        ),
      );
      return;
    }

    final currentQueueItem = queue.items[playableIndex];
    final upNext = queue.items.sublist(playableIndex + 1);
    final history = queue.items.sublist(0, playableIndex);

    final updatedQueue = queue.copyWith(
      currentIndex: playableIndex,
      upNextItems: upNext,
      originalUpNextItems: List.from(upNext),
      historyItems: history,
      manualItems: const [],
      smartItems: const [],
    );

    state = state.copyWith(queue: updatedQueue);
    await playTrack(currentQueueItem.trackId);

    if (updatedQueue.upcomingCount <= 2) {
      unawaited(_prefetchSmartQueue());
    }
  }

  /// Inserts a track immediately after currently playing track (head of manual queue).
  Future<void> playNext(QueueItem item) async {
    if (state.track == null || state.isIdle) {
      await playTrack(item.trackId);
      return;
    }
    final q = state.queue ?? const PlayerQueue(items: []);
    final updatedManual = [
      item.copyWith(source: QueueItemSource.manual),
      ...q.manualItems,
    ];
    state = state.copyWith(queue: q.copyWith(manualItems: updatedManual));
  }

  /// Appends a track to the user-managed manual queue.
  Future<void> addToQueue(QueueItem item) async {
    if (state.track == null || state.isIdle) {
      await playTrack(item.trackId);
      return;
    }
    final q = state.queue ?? const PlayerQueue(items: []);
    final updatedManual = [
      ...q.manualItems,
      item.copyWith(source: QueueItemSource.manual),
    ];
    state = state.copyWith(queue: q.copyWith(manualItems: updatedManual));
  }

  /// Removes an individual item from manual, upNext, or smart queue by queueItemId.
  void removeQueueItem(String queueItemId) {
    if (state.queue == null) return;
    final q = state.queue!;
    state = state.copyWith(
      queue: q.copyWith(
        manualItems:
            q.manualItems.where((i) => i.queueItemId != queueItemId).toList(),
        upNextItems:
            q.upNextItems.where((i) => i.queueItemId != queueItemId).toList(),
        smartItems:
            q.smartItems.where((i) => i.queueItemId != queueItemId).toList(),
      ),
    );
  }

  /// Drag-and-drop reorder for manual queue items.
  void reorderManualQueue(int oldIndex, int newIndex) {
    if (state.queue == null) return;
    final list = List<QueueItem>.from(state.queue!.manualItems);
    if (oldIndex < 0 || oldIndex >= list.length) return;
    if (newIndex > list.length) newIndex = list.length;
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = state.copyWith(
      queue: state.queue!.copyWith(manualItems: list),
    );
  }

  /// Drag-and-drop reorder for up-next items.
  void reorderUpNextQueue(int oldIndex, int newIndex) {
    if (state.queue == null) return;
    final list = List<QueueItem>.from(state.queue!.upNextItems);
    if (oldIndex < 0 || oldIndex >= list.length) return;
    if (newIndex > list.length) newIndex = list.length;
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = state.copyWith(
      queue: state.queue!.copyWith(upNextItems: list),
    );
  }

  /// Clears only user-added manual queue items.
  void clearManualQueue() {
    if (state.queue == null) return;
    state = state.copyWith(
      queue: state.queue!.copyWith(manualItems: const []),
    );
  }

  /// Clears all upcoming items (manual, up-next, smart).
  void clearAllUpcomingQueue() {
    if (state.queue == null) return;
    state = state.copyWith(
      queue: state.queue!.copyWith(
        manualItems: const [],
        upNextItems: const [],
        smartItems: const [],
      ),
    );
  }

  /// Toggles deterministic shuffle on upcoming tracks without modifying the currently playing track.
  void toggleShuffle() {
    if (state.queue == null) return;
    final q = state.queue!;
    if (!q.isShuffled) {
      final upNextToShuffle = List<QueueItem>.from(q.upNextItems);
      final backup = List<QueueItem>.from(upNextToShuffle);
      upNextToShuffle.shuffle();
      state = state.copyWith(
        queue: q.copyWith(
          isShuffled: true,
          upNextItems: upNextToShuffle,
          originalUpNextItems: backup,
        ),
      );
    } else {
      final currentUpNextIds =
          q.upNextItems.map((i) => i.queueItemId).toSet();
      final restored = q.originalUpNextItems
          .where((i) => currentUpNextIds.contains(i.queueItemId))
          .toList();
      state = state.copyWith(
        queue: q.copyWith(
          isShuffled: false,
          upNextItems: restored,
        ),
      );
    }
  }

  /// Cycles repeat mode: off -> repeatQueue -> repeatTrack -> off.
  void cycleRepeatMode() {
    if (state.queue == null) {
      state = state.copyWith(
        queue: const PlayerQueue(items: [], repeatMode: PlaybackRepeatMode.repeatQueue),
      );
      return;
    }
    final current = state.queue!.repeatMode;
    final next = switch (current) {
      PlaybackRepeatMode.off => PlaybackRepeatMode.repeatQueue,
      PlaybackRepeatMode.repeatQueue => PlaybackRepeatMode.repeatTrack,
      PlaybackRepeatMode.repeatTrack => PlaybackRepeatMode.off,
    };
    state = state.copyWith(
      queue: state.queue!.copyWith(repeatMode: next),
    );
  }

  /// Sets an explicit repeat mode.
  void setRepeatMode(PlaybackRepeatMode mode) {
    if (state.queue == null) {
      state = state.copyWith(
        queue: PlayerQueue(items: const [], repeatMode: mode),
      );
      return;
    }
    state = state.copyWith(
      queue: state.queue!.copyWith(repeatMode: mode),
    );
  }

  /// Skips to next track in queue with priority:
  /// Manual Queue -> Up Next -> Smart Queue -> Repeat Queue -> End.
  Future<void> skipToNext() async {
    final q = state.queue;
    if (q == null) return;

    await _emitPlaybackEvent('SKIPPED');
    await _checkpointProgress();

    final currentQueueItem = state.track != null
        ? QueueItem(
            trackId: state.track!.trackId,
            title: state.track!.title,
            artistName: state.track!.artistName,
            albumName: state.track!.albumName,
            durationSeconds: state.track!.durationSeconds,
            status: 'READY',
          )
        : null;

    final updatedHistory = [
      ...q.historyItems,
      ?currentQueueItem,
    ];

    // 1. Consume from manualItems first
    if (q.manualItems.isNotEmpty) {
      final nextItem = q.manualItems.first;
      final remainingManual = q.manualItems.sublist(1);
      final newQueue = q.copyWith(
        manualItems: remainingManual,
        historyItems: updatedHistory,
      );
      state = state.copyWith(queue: newQueue);
      await playTrack(nextItem.trackId);
      if (newQueue.upcomingCount <= 2) {
        unawaited(_prefetchSmartQueue());
      }
      return;
    }

    // 2. Consume from upNextItems
    if (q.upNextItems.isNotEmpty) {
      final nextItem = q.upNextItems.first;
      final remainingUpNext = q.upNextItems.sublist(1);
      final newQueue = q.copyWith(
        upNextItems: remainingUpNext,
        historyItems: updatedHistory,
      );
      state = state.copyWith(queue: newQueue);
      await playTrack(nextItem.trackId);
      if (newQueue.upcomingCount <= 2) {
        unawaited(_prefetchSmartQueue());
      }
      return;
    }

    // 3. Consume from smartItems
    if (q.smartItems.isNotEmpty) {
      final nextItem = q.smartItems.first;
      final remainingSmart = q.smartItems.sublist(1);
      final newQueue = q.copyWith(
        smartItems: remainingSmart,
        historyItems: updatedHistory,
      );
      state = state.copyWith(queue: newQueue);
      await playTrack(nextItem.trackId);
      if (newQueue.upcomingCount <= 2) {
        unawaited(_prefetchSmartQueue());
      }
      return;
    }

    // 4. Repeat Queue mode: loop back through history / original items
    if (q.repeatMode == PlaybackRepeatMode.repeatQueue &&
        (q.historyItems.isNotEmpty || q.items.isNotEmpty)) {
      final allItems = q.originalUpNextItems.isNotEmpty
          ? q.originalUpNextItems
          : (q.items.isNotEmpty ? q.items : q.historyItems);
      if (allItems.isNotEmpty) {
        final nextItem = allItems.first;
        final upNext = allItems.sublist(1);
        final newQueue = q.copyWith(
          upNextItems: upNext,
          historyItems: const [],
          manualItems: const [],
          smartItems: const [],
        );
        state = state.copyWith(queue: newQueue);
        await playTrack(nextItem.trackId);
        return;
      }
    }

    // 5. Fallback for legacy items queue index
    if (q.nextIndex != null) {
      final nextIdx = q.nextIndex!;
      final nextItem = q.items[nextIdx];
      state = state.copyWith(queue: q.copyWith(currentIndex: nextIdx));
      await playTrack(nextItem.trackId);
      return;
    }

    state = state.copyWith(status: PlayerStatus.completed);
  }

  /// Skips to previous track or seeks to beginning if > 3 seconds into track.
  Future<void> skipToPrevious() async {
    if (state.position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }

    final q = state.queue;
    if (q == null) {
      await seek(Duration.zero);
      return;
    }

    if (q.historyItems.isNotEmpty) {
      await _emitPlaybackEvent('SKIPPED');
      await _checkpointProgress();

      final previousItem = q.historyItems.last;
      final remainingHistory =
          q.historyItems.sublist(0, q.historyItems.length - 1);

      final currentQueueItem = state.track != null
          ? QueueItem(
              trackId: state.track!.trackId,
              title: state.track!.title,
              artistName: state.track!.artistName,
              albumName: state.track!.albumName,
              durationSeconds: state.track!.durationSeconds,
            )
          : null;

      final updatedUpNext = [
        ?currentQueueItem,
        ...q.upNextItems,
      ];

      state = state.copyWith(
        queue: q.copyWith(
          historyItems: remainingHistory,
          upNextItems: updatedUpNext,
        ),
      );
      await playTrack(previousItem.trackId);
      return;
    }

    if (q.previousIndex != null) {
      await _emitPlaybackEvent('SKIPPED');
      await _checkpointProgress();
      final prevIdx = q.previousIndex!;
      final prevItem = q.items[prevIdx];
      state = state.copyWith(queue: q.copyWith(currentIndex: prevIdx));
      await playTrack(prevItem.trackId);
      return;
    }

    await seek(Duration.zero);
  }

  Future<void> retry() async {
    if (state.track != null) {
      await playTrack(state.track!.trackId);
    }
  }

  Future<void> stop() async {
    try {
      _stopCheckpointTimer();
      await _emitPlaybackEvent('STOPPED');
      await _checkpointProgress();
      await _repository.stop();
      state = state.copyWith(
        status: PlayerStatus.idle,
        position: Duration.zero,
      );
    } catch (_) {}
  }

  /// Clears active queue on logout to isolate account sessions.
  void resetQueueOnLogout() {
    _stopCheckpointTimer();
    _repository.stop();
    state = const PlayerState();
  }

  /// Checkpoints progress when app enters background or is inactive.
  Future<void> checkpointCurrentProgress() async {
    if (state.track != null && (state.isPlaying || state.isPaused)) {
      await _checkpointProgress();
    }
  }

  @override
  void dispose() {
    _stopCheckpointTimer();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _bufferedSub?.cancel();
    _playingSub?.cancel();
    _bufferingSub?.cancel();
    _completedSub?.cancel();
    super.dispose();
  }
}
