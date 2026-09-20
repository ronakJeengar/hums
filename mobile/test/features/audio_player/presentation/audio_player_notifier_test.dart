import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hums_mobile/features/audio_player/domain/entities/playback_entity.dart';
import 'package:hums_mobile/features/audio_player/domain/entities/player_error.dart';
import 'package:hums_mobile/features/audio_player/domain/repositories/audio_player_repository.dart';
import 'package:hums_mobile/features/audio_player/presentation/providers/audio_player_provider.dart';
import 'package:hums_mobile/features/audio_player/presentation/states/player_state.dart';

class MockAudioPlayerRepository extends Mock implements AudioPlayerRepository {}

void main() {
  late MockAudioPlayerRepository mockRepository;
  late StreamController<Duration> positionController;
  late StreamController<Duration?> durationController;
  late StreamController<Duration> bufferedController;
  late StreamController<bool> isPlayingController;
  late StreamController<bool> isBufferingController;
  late StreamController<bool> isCompletedController;
  late AudioPlayerNotifier notifier;

  const tTrackPlayback = TrackPlaybackEntity(
    trackId: 'track-100',
    title: 'Warm Acoustic',
    artistName: 'Test Artist',
    albumName: 'Acoustics',
    genre: 'Folk',
    durationSeconds: 200,
    status: 'READY',
    audio: AudioSourceEntity(
      url: 'https://cdn.hums.app/stream/track-100/audio.mp3',
      format: 'mp3',
      codec: 'mp3',
      bitrateKbps: 192,
      durationSeconds: 200,
      fileSizeBytes: 5000000,
    ),
    waveformSamples: [0.2, 0.5, 0.9, 0.4],
  );

  setUpAll(() {
    registerFallbackValue(Duration.zero);
  });

  setUp(() {
    mockRepository = MockAudioPlayerRepository();
    positionController = StreamController<Duration>.broadcast();
    durationController = StreamController<Duration?>.broadcast();
    bufferedController = StreamController<Duration>.broadcast();
    isPlayingController = StreamController<bool>.broadcast();
    isBufferingController = StreamController<bool>.broadcast();
    isCompletedController = StreamController<bool>.broadcast();

    when(() => mockRepository.positionStream)
        .thenAnswer((_) => positionController.stream);
    when(() => mockRepository.durationStream)
        .thenAnswer((_) => durationController.stream);
    when(() => mockRepository.bufferedPositionStream)
        .thenAnswer((_) => bufferedController.stream);
    when(() => mockRepository.isPlayingStream)
        .thenAnswer((_) => isPlayingController.stream);
    when(() => mockRepository.isBufferingStream)
        .thenAnswer((_) => isBufferingController.stream);
    when(() => mockRepository.isCompletedStream)
        .thenAnswer((_) => isCompletedController.stream);

    notifier = AudioPlayerNotifier(mockRepository);
  });

  tearDown(() {
    notifier.dispose();
    positionController.close();
    durationController.close();
    bufferedController.close();
    isPlayingController.close();
    isBufferingController.close();
    isCompletedController.close();
  });

  group('AudioPlayerNotifier Tests', () {
    test('initial state is idle with zero position', () {
      expect(notifier.state.status, PlayerStatus.idle);
      expect(notifier.state.track, isNull);
      expect(notifier.state.position, Duration.zero);
      expect(notifier.state.duration, Duration.zero);
      expect(notifier.state.error, isNull);
    });

    test('playTrack successfully loads and starts playing', () async {
      when(() => mockRepository.getPlaybackSource('track-100'))
          .thenAnswer((_) async => tTrackPlayback);
      when(() => mockRepository.loadTrack(tTrackPlayback))
          .thenAnswer((_) async {});
      when(() => mockRepository.play()).thenAnswer((_) async {});

      final future = notifier.playTrack('track-100');

      // State is immediately set to loading
      expect(notifier.state.status, PlayerStatus.loading);

      await future;

      expect(notifier.state.status, PlayerStatus.playing);
      expect(notifier.state.track?.trackId, 'track-100');
      expect(notifier.state.duration, const Duration(seconds: 200));
      verify(() => mockRepository.getPlaybackSource('track-100')).called(1);
      verify(() => mockRepository.loadTrack(tTrackPlayback)).called(1);
      verify(() => mockRepository.play()).called(1);
    });

    test('playTrack sets error state when getPlaybackSource fails', () async {
      when(() => mockRepository.getPlaybackSource('track-100')).thenThrow(
        const PlayerError(
          type: PlayerErrorType.sourceUnavailable,
          message: 'Track is not ready',
        ),
      );

      await notifier.playTrack('track-100');

      expect(notifier.state.status, PlayerStatus.error);
      expect(notifier.state.error?.type, PlayerErrorType.sourceUnavailable);
      expect(notifier.state.error?.message, 'Track is not ready');
    });

    test('togglePlayPause pauses when playing and resumes when paused',
        () async {
      when(() => mockRepository.getPlaybackSource('track-100'))
          .thenAnswer((_) async => tTrackPlayback);
      when(() => mockRepository.loadTrack(tTrackPlayback))
          .thenAnswer((_) async {});
      when(() => mockRepository.play()).thenAnswer((_) async {});
      when(() => mockRepository.pause()).thenAnswer((_) async {});
      when(() => mockRepository.resume()).thenAnswer((_) async {});

      await notifier.playTrack('track-100');
      expect(notifier.state.isPlaying, isTrue);

      // Pause
      await notifier.togglePlayPause();
      verify(() => mockRepository.pause()).called(1);

      // Simulate stream emitting paused
      isPlayingController.add(false);
      await Future<void>.delayed(Duration.zero);
      expect(notifier.state.isPaused, isTrue);

      // Resume
      await notifier.togglePlayPause();
      verify(() => mockRepository.resume()).called(1);
    });

    test('seekBackward10 calls seekRelative(-10s)', () async {
      when(() => mockRepository.seek(any())).thenAnswer((_) async {});

      await notifier.seekBackward10();

      verify(() => mockRepository.seek(Duration.zero)).called(1);
    });

    test('seekForward30 calls seekRelative(+30s)', () async {
      when(() => mockRepository.seek(any())).thenAnswer((_) async {});

      await notifier.seekForward30();

      verify(() => mockRepository.seek(const Duration(seconds: 30))).called(1);
    });

    test('stop calls repository.stop and resets state to idle', () async {
      when(() => mockRepository.stop()).thenAnswer((_) async {});

      await notifier.stop();

      expect(notifier.state.status, PlayerStatus.idle);
      expect(notifier.state.position, Duration.zero);
      verify(() => mockRepository.stop()).called(1);
    });

    test('stream updates reflect in PlayerState', () async {
      positionController.add(const Duration(seconds: 42));
      durationController.add(const Duration(seconds: 240));
      bufferedController.add(const Duration(seconds: 80));

      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.position, const Duration(seconds: 42));
      expect(notifier.state.duration, const Duration(seconds: 240));
      expect(notifier.state.bufferedPosition, const Duration(seconds: 80));
      expect(notifier.state.progress, closeTo(42 / 240, 0.001));
      expect(notifier.state.bufferedProgress, closeTo(80 / 240, 0.001));
    });
  });
}
