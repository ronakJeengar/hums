import 'package:hums_mobile/features/audio_player/domain/entities/playback_entity.dart';
import 'package:hums_mobile/features/audio_player/domain/entities/player_error.dart';
import 'package:hums_mobile/features/audio_player/domain/entities/player_queue.dart';

enum PlayerStatus {
  idle,
  loading,
  ready,
  playing,
  paused,
  buffering,
  completed,
  error,
}

class PlayerState {
  final PlayerStatus status;
  final TrackPlaybackEntity? track;
  final Duration position;
  final Duration duration;
  final Duration bufferedPosition;
  final PlayerError? error;
  final PlayerQueue? queue;

  const PlayerState({
    this.status = PlayerStatus.idle,
    this.track,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.bufferedPosition = Duration.zero,
    this.error,
    this.queue,
  });

  PlayerState copyWith({
    PlayerStatus? status,
    TrackPlaybackEntity? track,
    Duration? position,
    Duration? duration,
    Duration? bufferedPosition,
    PlayerError? error,
    PlayerQueue? queue,
    bool clearError = false,
    bool clearQueue = false,
  }) {
    return PlayerState(
      status: status ?? this.status,
      track: track ?? this.track,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      bufferedPosition: bufferedPosition ?? this.bufferedPosition,
      error: clearError ? null : (error ?? this.error),
      queue: clearQueue ? null : (queue ?? this.queue),
    );
  }

  bool get isIdle => status == PlayerStatus.idle;
  bool get isLoading => status == PlayerStatus.loading;
  bool get isReady => status == PlayerStatus.ready;
  bool get isPlaying => status == PlayerStatus.playing;
  bool get isPaused => status == PlayerStatus.paused;
  bool get isBuffering => status == PlayerStatus.buffering;
  bool get isCompleted => status == PlayerStatus.completed;
  bool get isError => status == PlayerStatus.error;

  bool get hasTrack => track != null;
  bool get canPlay => hasTrack && (isReady || isPaused || isCompleted);
  bool get hasQueue => queue != null && queue!.items.isNotEmpty;
  bool get hasNext => queue?.hasNext ?? false;
  bool get hasPrevious => queue?.hasPrevious ?? false;

  double get progress {
    if (duration.inMilliseconds <= 0) return 0.0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  double get bufferedProgress {
    if (duration.inMilliseconds <= 0) return 0.0;
    return (bufferedPosition.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayerState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          track == other.track &&
          position == other.position &&
          duration == other.duration &&
          bufferedPosition == other.bufferedPosition &&
          error == other.error &&
          queue == other.queue;

  @override
  int get hashCode => Object.hash(
        runtimeType,
        status,
        track,
        position,
        duration,
        bufferedPosition,
        error,
        queue,
      );

  @override
  String toString() =>
      'PlayerState(status: $status, track: ${track?.title}, position: $position, duration: $duration, queue: ${queue?.playlistName}, error: $error)';
}
