import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hums_mobile/core/network/api_exception.dart';
import 'package:hums_mobile/features/audio_player/data/datasources/audio_player_remote_data_source.dart';
import 'package:hums_mobile/features/audio_player/data/models/playback_model.dart';
import 'package:hums_mobile/features/audio_player/data/repositories/audio_player_repository_impl.dart';
import 'package:hums_mobile/features/audio_player/data/services/audio_player_service.dart';
import 'package:hums_mobile/features/audio_player/domain/entities/player_error.dart';

class MockAudioPlayerRemoteDataSource extends Mock
    implements AudioPlayerRemoteDataSource {}

class MockAudioPlayerService extends Mock implements AudioPlayerService {}

void main() {
  late MockAudioPlayerRemoteDataSource mockRemote;
  late MockAudioPlayerService mockService;
  late AudioPlayerRepositoryImpl repository;

  setUp(() {
    mockRemote = MockAudioPlayerRemoteDataSource();
    mockService = MockAudioPlayerService();
    repository = AudioPlayerRepositoryImpl(mockRemote, mockService);
  });

  const tAudioSourceModel = AudioSourceModel(
    url: 'https://cdn.hums.app/stream/track-1/audio.mp3',
    format: 'mp3',
    codec: 'mp3',
    bitrateKbps: 192,
    durationSeconds: 180,
    fileSizeBytes: 4500000,
  );

  const tPlaybackModel = TrackPlaybackModel(
    trackId: 'track-1',
    title: 'Acoustic Serenade',
    artistName: 'Ronak',
    albumName: 'Unplugged',
    genre: 'Acoustic',
    durationSeconds: 180,
    status: 'READY',
    audio: tAudioSourceModel,
    waveformSamples: [0.1, 0.4, 0.8, 0.5, 0.2],
  );

  final tPlaybackEntity = tPlaybackModel.toEntity();

  group('AudioPlayerRepositoryImpl - getPlaybackSource', () {
    test('successfully fetches and converts playback model to entity',
        () async {
      when(() => mockRemote.getPlaybackSource('track-1'))
          .thenAnswer((_) async => tPlaybackModel);

      final result = await repository.getPlaybackSource('track-1');

      expect(result.trackId, 'track-1');
      expect(result.title, 'Acoustic Serenade');
      expect(result.audio.format, 'mp3');
      expect(result.audio.bitrateKbps, 192);
      expect(result.waveformSamples, [0.1, 0.4, 0.8, 0.5, 0.2]);
      verify(() => mockRemote.getPlaybackSource('track-1')).called(1);
    });

    test('throws PlayerError with sourceUnavailable when track is not ready (409)',
        () async {
      when(() => mockRemote.getPlaybackSource('track-1')).thenThrow(
        const ApiException(
          message: 'Track is processing',
          statusCode: 409,
          code: 'TRACK_NOT_READY',
        ),
      );

      expect(
        () => repository.getPlaybackSource('track-1'),
        throwsA(
          isA<PlayerError>().having(
            (e) => e.type,
            'type',
            PlayerErrorType.sourceUnavailable,
          ),
        ),
      );
    });

    test('throws PlayerError with unauthorized when user is not signed in (401)',
        () async {
      when(() => mockRemote.getPlaybackSource('track-1')).thenThrow(
        const ApiException(
          message: 'Not authorized',
          statusCode: 401,
          code: 'UNAUTHORIZED',
        ),
      );

      expect(
        () => repository.getPlaybackSource('track-1'),
        throwsA(
          isA<PlayerError>().having(
            (e) => e.type,
            'type',
            PlayerErrorType.unauthorized,
          ),
        ),
      );
    });

    test('throws PlayerError with networkError on generic ApiException',
        () async {
      when(() => mockRemote.getPlaybackSource('track-1')).thenThrow(
        const ApiException(
          message: 'Connection failed',
          statusCode: 500,
          code: 'SERVER_ERROR',
        ),
      );

      expect(
        () => repository.getPlaybackSource('track-1'),
        throwsA(
          isA<PlayerError>().having(
            (e) => e.type,
            'type',
            PlayerErrorType.networkError,
          ),
        ),
      );
    });
  });

  group('AudioPlayerRepositoryImpl - Playback Operations', () {
    test('loadTrack delegates to audioPlayerService', () async {
      when(() => mockService.loadTrack(tPlaybackEntity))
          .thenAnswer((_) async {});

      await repository.loadTrack(tPlaybackEntity);

      verify(() => mockService.loadTrack(tPlaybackEntity)).called(1);
    });

    test('play delegates to audioPlayerService', () async {
      when(() => mockService.play()).thenAnswer((_) async {});

      await repository.play();

      verify(() => mockService.play()).called(1);
    });

    test('pause delegates to audioPlayerService', () async {
      when(() => mockService.pause()).thenAnswer((_) async {});

      await repository.pause();

      verify(() => mockService.pause()).called(1);
    });

    test('resume delegates to audioPlayerService', () async {
      when(() => mockService.resume()).thenAnswer((_) async {});

      await repository.resume();

      verify(() => mockService.resume()).called(1);
    });

    test('seek delegates to audioPlayerService', () async {
      when(() => mockService.seek(const Duration(seconds: 45)))
          .thenAnswer((_) async {});

      await repository.seek(const Duration(seconds: 45));

      verify(() => mockService.seek(const Duration(seconds: 45))).called(1);
    });

    test('seekRelative delegates to audioPlayerService', () async {
      when(() => mockService.seekRelative(const Duration(seconds: -10)))
          .thenAnswer((_) async {});

      await repository.seekRelative(const Duration(seconds: -10));

      verify(() => mockService.seekRelative(const Duration(seconds: -10)))
          .called(1);
    });

    test('stop delegates to audioPlayerService', () async {
      when(() => mockService.stop()).thenAnswer((_) async {});

      await repository.stop();

      verify(() => mockService.stop()).called(1);
    });

    test('dispose delegates to audioPlayerService', () async {
      when(() => mockService.dispose()).thenAnswer((_) async {});

      await repository.dispose();

      verify(() => mockService.dispose()).called(1);
    });
  });

  group('AudioPlayerRepositoryImpl - Streams', () {
    test('positionStream delegates to audioPlayerService', () {
      final stream = Stream.value(const Duration(seconds: 10));
      when(() => mockService.positionStream).thenAnswer((_) => stream);

      expect(repository.positionStream, stream);
    });

    test('durationStream delegates to audioPlayerService', () {
      final stream = Stream.value(const Duration(seconds: 180));
      when(() => mockService.durationStream).thenAnswer((_) => stream);

      expect(repository.durationStream, stream);
    });

    test('isPlayingStream delegates to audioPlayerService', () {
      final stream = Stream.value(true);
      when(() => mockService.isPlayingStream).thenAnswer((_) => stream);

      expect(repository.isPlayingStream, stream);
    });
  });
}
