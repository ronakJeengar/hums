import 'dart:async';
import 'dart:io';
import 'package:hums_mobile/core/network/api_exception.dart';
import 'package:hums_mobile/features/audio_player/data/datasources/audio_player_remote_data_source.dart';
import 'package:hums_mobile/features/audio_player/data/services/audio_player_service.dart';
import 'package:hums_mobile/features/audio_player/domain/entities/playback_entity.dart';
import 'package:hums_mobile/features/audio_player/domain/entities/player_error.dart';
import 'package:hums_mobile/features/audio_player/domain/repositories/audio_player_repository.dart';
import 'package:hums_mobile/features/downloads/data/datasources/download_local_data_source.dart';
import 'package:hums_mobile/features/downloads/domain/entities/download_status.dart';

class AudioPlayerRepositoryImpl implements AudioPlayerRepository {
  final AudioPlayerRemoteDataSource _remoteDataSource;
  final AudioPlayerService _audioPlayerService;
  final DownloadLocalDataSource? _downloadLocalDataSource;

  AudioPlayerRepositoryImpl(
    this._remoteDataSource,
    this._audioPlayerService, [
    this._downloadLocalDataSource,
  ]);

  @override
  Future<TrackPlaybackEntity> getPlaybackSource(String trackId) async {
    // 1. Check if track is downloaded locally for offline playback
    if (_downloadLocalDataSource != null) {
      try {
        final download = await _downloadLocalDataSource.getDownload(trackId);
        if (download != null &&
            download.status == DownloadStatus.completed &&
            download.localPath != null) {
          final file = File(download.localPath!);
          if (await file.exists() && await file.length() > 0) {
            return TrackPlaybackEntity(
              trackId: download.trackId,
              title: download.title,
              artistName: download.artistName,
              albumName: download.albumName,
              durationSeconds: download.durationSeconds,
              status: 'READY',
              audio: AudioSourceEntity(
                url: download.localPath!,
                format: download.format,
                codec: download.format == 'mp3' ? 'mp3' : 'aac',
                bitrateKbps: download.audioBitrate ?? 320,
                durationSeconds: download.durationSeconds,
                fileSizeBytes: download.totalBytes,
              ),
              waveformSamples: download.waveformSamples,
            );
          }
        }
      } catch (_) {
        // Fall back to remote fetch if local check encounters error
      }
    }

    try {
      final model = await _remoteDataSource.getPlaybackSource(trackId);
      return model.toEntity();
    } on ApiException catch (e) {
      if (e.statusCode == 409 || e.code == 'TRACK_NOT_READY') {
        throw PlayerError(
          type: PlayerErrorType.sourceUnavailable,
          message: 'This track is still being processed and is not ready for playback.',
          details: e.message,
        );
      } else if (e.statusCode == 401) {
        throw PlayerError(
          type: PlayerErrorType.unauthorized,
          message: 'Please sign in to play this track.',
          details: e.message,
        );
      } else {
        throw PlayerError(
          type: PlayerErrorType.networkError,
          message: e.message,
          details: e.details.toString(),
        );
      }
    } catch (e) {
      if (e is PlayerError) rethrow;
      throw PlayerError(
        type: PlayerErrorType.unknown,
        message: 'Failed to retrieve playback source: $e',
        details: e.toString(),
      );
    }
  }

  @override
  Future<void> loadTrack(TrackPlaybackEntity playback) async {
    await _audioPlayerService.loadTrack(playback);
  }

  @override
  Future<void> play() async {
    await _audioPlayerService.play();
  }

  @override
  Future<void> pause() async {
    await _audioPlayerService.pause();
  }

  @override
  Future<void> resume() async {
    await _audioPlayerService.resume();
  }

  @override
  Future<void> seek(Duration position) async {
    await _audioPlayerService.seek(position);
  }

  @override
  Future<void> seekRelative(Duration offset) async {
    await _audioPlayerService.seekRelative(offset);
  }

  @override
  Future<void> stop() async {
    await _audioPlayerService.stop();
  }

  @override
  Future<void> dispose() async {
    await _audioPlayerService.dispose();
  }

  @override
  Stream<Duration> get positionStream => _audioPlayerService.positionStream;

  @override
  Stream<Duration?> get durationStream => _audioPlayerService.durationStream;

  @override
  Stream<Duration> get bufferedPositionStream => _audioPlayerService.bufferedPositionStream;

  @override
  Stream<bool> get isPlayingStream => _audioPlayerService.isPlayingStream;

  @override
  Stream<bool> get isBufferingStream => _audioPlayerService.isBufferingStream;

  @override
  Stream<bool> get isCompletedStream => _audioPlayerService.isCompletedStream;
}
