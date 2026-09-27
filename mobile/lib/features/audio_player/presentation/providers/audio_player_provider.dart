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
  return AudioPlayerNotifier(repository, historyRepo);
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

        if (state.hasNext) {
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

    final updatedQueue = queue.copyWith(currentIndex: playableIndex);
    state = state.copyWith(queue: updatedQueue);
    await playTrack(updatedQueue.items[playableIndex].trackId);
  }

  Future<void> skipToNext() async {
    if (state.hasNext && state.queue != null) {
      await _emitPlaybackEvent('SKIPPED');
      await _checkpointProgress();
      final nextIdx = state.queue!.nextIndex!;
      final nextItem = state.queue!.items[nextIdx];
      state = state.copyWith(queue: state.queue!.copyWith(currentIndex: nextIdx));
      await playTrack(nextItem.trackId);
    }
  }

  Future<void> skipToPrevious() async {
    if (state.position.inSeconds > 3) {
      await seek(Duration.zero);
    } else if (state.hasPrevious && state.queue != null) {
      await _emitPlaybackEvent('SKIPPED');
      await _checkpointProgress();
      final prevIdx = state.queue!.previousIndex!;
      final prevItem = state.queue!.items[prevIdx];
      state = state.copyWith(queue: state.queue!.copyWith(currentIndex: prevIdx));
      await playTrack(prevItem.trackId);
    } else {
      await seek(Duration.zero);
    }
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
