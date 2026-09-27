import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:hums_mobile/features/audio_player/domain/entities/playback_entity.dart';
import 'package:hums_mobile/features/audio_player/domain/entities/player_error.dart';

class AudioPlayerService {
  final AudioPlayer _player;

  AudioPlayerService({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  AudioPlayer get player => _player;

  /// Loads and prepares a track source with background media metadata.
  Future<void> loadTrack(TrackPlaybackEntity track) async {
    try {
      final mediaItem = MediaItem(
        id: track.trackId,
        title: track.title,
        artist: track.artistName ?? 'Unknown Artist',
        album: track.albumName ?? 'Hums',
        duration: track.durationSeconds != null
            ? Duration(seconds: track.durationSeconds!)
            : null,
      );

      final AudioSource audioSource;
      final url = track.audio.url;
      if (url.startsWith('file://')) {
        final filePath = Uri.parse(url).toFilePath();
        audioSource = AudioSource.file(filePath, tag: mediaItem);
      } else if (!url.startsWith('http://') && !url.startsWith('https://')) {
        audioSource = AudioSource.file(url, tag: mediaItem);
      } else {
        audioSource = AudioSource.uri(
          Uri.parse(url),
          tag: mediaItem,
        );
      }

      await _player.setAudioSource(audioSource);
    } on PlayerException catch (e) {
      throw PlayerError(
        type: PlayerErrorType.audioLoadFailed,
        message: 'Unable to load audio: ${e.message}',
        details: e.toString(),
      );
    } catch (e) {
      throw PlayerError(
        type: PlayerErrorType.unknown,
        message: 'Unexpected playback error: $e',
        details: e.toString(),
      );
    }
  }

  Future<void> play() async {
    try {
      await _player.play();
    } catch (e) {
      throw PlayerError(
        type: PlayerErrorType.unknown,
        message: 'Failed to start playback: $e',
      );
    }
  }

  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (e) {
      throw PlayerError(
        type: PlayerErrorType.unknown,
        message: 'Failed to pause playback: $e',
      );
    }
  }

  Future<void> resume() async {
    try {
      await _player.play();
    } catch (e) {
      throw PlayerError(
        type: PlayerErrorType.unknown,
        message: 'Failed to resume playback: $e',
      );
    }
  }

  Future<void> seek(Duration position) async {
    try {
      final duration = _player.duration ?? Duration.zero;
      final target = position < Duration.zero
          ? Duration.zero
          : (duration > Duration.zero && position > duration
              ? duration
              : position);
      await _player.seek(target);
    } catch (e) {
      throw PlayerError(
        type: PlayerErrorType.unknown,
        message: 'Failed to seek: $e',
      );
    }
  }

  Future<void> seekRelative(Duration offset) async {
    final current = _player.position;
    await seek(current + offset);
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (e) {
      throw PlayerError(
        type: PlayerErrorType.unknown,
        message: 'Failed to stop playback: $e',
      );
    }
  }

  Future<void> dispose() async {
    await _player.dispose();
  }

  Stream<Duration> get positionStream => _player.positionStream;

  Stream<Duration?> get durationStream => _player.durationStream;

  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream;

  Stream<bool> get isPlayingStream => _player.playingStream;

  Stream<bool> get isBufferingStream => _player.processingStateStream.map(
        (state) =>
            state == ProcessingState.buffering ||
            state == ProcessingState.loading,
      );

  Stream<bool> get isCompletedStream => _player.processingStateStream.map(
        (state) => state == ProcessingState.completed,
      );
}
