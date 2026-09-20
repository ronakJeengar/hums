import 'package:hums_mobile/features/audio_player/domain/entities/playback_entity.dart';

abstract class AudioPlayerRepository {
  /// Fetches the playback source and metadata for a READY track.
  Future<TrackPlaybackEntity> getPlaybackSource(String trackId);

  /// Loads and prepares a track for playback in the audio engine.
  Future<void> loadTrack(TrackPlaybackEntity playback);

  /// Begins or resumes audio playback.
  Future<void> play();

  /// Pauses audio playback.
  Future<void> pause();

  /// Resumes audio playback.
  Future<void> resume();

  /// Seeks to an absolute position within the current track.
  Future<void> seek(Duration position);

  /// Seeks relative to the current playback position (+/- offset).
  Future<void> seekRelative(Duration offset);

  /// Stops audio playback and resets position.
  Future<void> stop();

  /// Disposes the underlying audio engine.
  Future<void> dispose();

  /// Stream of current playback position.
  Stream<Duration> get positionStream;

  /// Stream of current track duration.
  Stream<Duration?> get durationStream;

  /// Stream of buffered position.
  Stream<Duration> get bufferedPositionStream;

  /// Stream of playing state (true if actively playing).
  Stream<bool> get isPlayingStream;

  /// Stream of buffering state (true if actively buffering).
  Stream<bool> get isBufferingStream;

  /// Stream of track completion events.
  Stream<bool> get isCompletedStream;
}
