import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hums_mobile/core/network/api_exception.dart';
import 'package:hums_mobile/features/audio_player/data/datasources/audio_player_remote_data_source.dart';
import 'package:hums_mobile/features/audio_player/data/models/playback_model.dart';
import 'package:hums_mobile/features/audio_player/data/repositories/audio_player_repository_impl.dart';
import 'package:hums_mobile/features/audio_player/data/services/audio_player_service.dart';
import 'package:hums_mobile/features/audio_player/domain/entities/player_error.dart';
import 'package:hums_mobile/features/downloads/data/datasources/download_local_data_source.dart';
import 'package:hums_mobile/features/downloads/domain/entities/download_item.dart';
import 'package:hums_mobile/features/downloads/domain/entities/download_status.dart';

class MockAudioPlayerRemoteDataSource extends Mock
    implements AudioPlayerRemoteDataSource {}

class MockAudioPlayerService extends Mock implements AudioPlayerService {}

class MockDownloadLocalDataSource extends Mock
    implements DownloadLocalDataSource {}

void main() {
  late MockAudioPlayerRemoteDataSource mockRemote;
  late MockAudioPlayerService mockService;
  late MockDownloadLocalDataSource mockDownloadLocal;
  late AudioPlayerRepositoryImpl repository;
  late File tempAudioFile;

  setUp(() async {
    mockRemote = MockAudioPlayerRemoteDataSource();
    mockService = MockAudioPlayerService();
    mockDownloadLocal = MockDownloadLocalDataSource();
    repository = AudioPlayerRepositoryImpl(
      mockRemote,
      mockService,
      mockDownloadLocal,
    );

    // Create a dummy local audio file to satisfy file.existsSync() checks
    final dir = await Directory.systemTemp.createTemp('hums_audio_test_');
    tempAudioFile = File('${dir.path}/audio.m4a');
    await tempAudioFile.writeAsBytes(List.filled(1024, 0));
  });

  tearDown(() async {
    if (await tempAudioFile.exists()) {
      await tempAudioFile.parent.delete(recursive: true);
    }
  });

  final now = DateTime.now();

  group('AudioPlayerRepositoryImpl - Offline Local Playback', () {
    test('serves local file source when track is downloaded and ready offline',
        () async {
      final completedDownload = DownloadItem(
        id: 'dl_track1',
        trackId: 'track-1',
        userId: 'user_1',
        title: 'Offline Masterpiece',
        artistName: 'Ronak',
        albumName: 'Acoustics',
        durationSeconds: 210,
        status: DownloadStatus.completed,
        localPath: tempAudioFile.path,
        format: 'm4a',
        audioBitrate: 256,
        totalBytes: 1024,
        waveformSamples: [0.1, 0.5, 0.9],
        createdAt: now,
        updatedAt: now,
      );

      when(() => mockDownloadLocal.getDownload('track-1'))
          .thenAnswer((_) async => completedDownload);

      final result = await repository.getPlaybackSource('track-1');

      // Verify remote network dataSource was NOT called
      verifyNever(() => mockRemote.getPlaybackSource(any()));

      expect(result.trackId, 'track-1');
      expect(result.title, 'Offline Masterpiece');
      expect(result.audio.url, tempAudioFile.path);
      expect(result.audio.format, 'm4a');
      expect(result.audio.bitrateKbps, 256);
      expect(result.waveformSamples, [0.1, 0.5, 0.9]);
    });

    test('falls back to remote API when track is NOT downloaded', () async {
      const tPlaybackModel = TrackPlaybackModel(
        trackId: 'track-2',
        title: 'Streaming Only',
        artistName: 'Ronak',
        albumName: 'Cloud',
        status: 'READY',
        audio: AudioSourceModel(
          url: 'https://cdn.hums.app/stream/track-2/audio.mp3',
          format: 'mp3',
          codec: 'mp3',
          bitrateKbps: 192,
          fileSizeBytes: 3000000,
        ),
      );

      when(() => mockDownloadLocal.getDownload('track-2'))
          .thenAnswer((_) async => null);
      when(() => mockRemote.getPlaybackSource('track-2'))
          .thenAnswer((_) async => tPlaybackModel);

      final result = await repository.getPlaybackSource('track-2');

      verify(() => mockRemote.getPlaybackSource('track-2')).called(1);
      expect(result.trackId, 'track-2');
      expect(result.audio.url, 'https://cdn.hums.app/stream/track-2/audio.mp3');
    });

    test('throws PlayerError when not downloaded and network is offline', () async {
      when(() => mockDownloadLocal.getDownload('track-3'))
          .thenAnswer((_) async => null);
      when(() => mockRemote.getPlaybackSource('track-3')).thenThrow(
        ApiException.network('No internet connection'),
      );

      expect(
        () => repository.getPlaybackSource('track-3'),
        throwsA(isA<PlayerError>()),
      );
    });
  });
}
