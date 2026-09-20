import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hums_mobile/features/audio_player/domain/entities/playback_entity.dart';
import 'package:hums_mobile/features/audio_player/presentation/providers/audio_player_provider.dart';
import 'package:hums_mobile/features/audio_player/presentation/states/player_state.dart';
import 'package:hums_mobile/features/audio_player/presentation/widgets/mini_player.dart';

class MockAudioPlayerNotifier extends StateNotifier<PlayerState>
    with Mock
    implements AudioPlayerNotifier {
  MockAudioPlayerNotifier(super.state);
}

void main() {
  const tTrackPlayback = TrackPlaybackEntity(
    trackId: 'track-1',
    title: 'Acoustic Groove',
    artistName: 'Luna Wave',
    albumName: 'Echoes',
    genre: 'Acoustic',
    durationSeconds: 180,
    status: 'READY',
    audio: AudioSourceEntity(
      url: 'https://cdn.hums.app/stream/track-1/audio.mp3',
      format: 'mp3',
      codec: 'mp3',
      bitrateKbps: 192,
      durationSeconds: 180,
      fileSizeBytes: 4500000,
    ),
  );

  Widget createWidgetUnderTest(PlayerState state, {MockAudioPlayerNotifier? notifier}) {
    return ProviderScope(
      overrides: [
        audioPlayerNotifierProvider.overrideWith((ref) {
          return notifier ?? MockAudioPlayerNotifier(state);
        }),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Background')),
          bottomNavigationBar: MiniPlayer(),
        ),
      ),
    );
  }

  group('MiniPlayer Widget Tests', () {
    testWidgets('renders empty SizedBox when no track is active',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(const PlayerState(status: PlayerStatus.idle)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Acoustic Groove'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('renders track title, artist, and progress when track is active',
        (WidgetTester tester) async {
      const state = PlayerState(
        status: PlayerStatus.playing,
        track: tTrackPlayback,
        position: Duration(seconds: 45),
        duration: Duration(seconds: 180),
      );

      await tester.pumpWidget(createWidgetUnderTest(state));
      await tester.pumpAndSettle();

      expect(find.text('Acoustic Groove'), findsOneWidget);
      expect(find.text('Luna Wave'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('taps play/pause button to toggle playback',
        (WidgetTester tester) async {
      const state = PlayerState(
        status: PlayerStatus.playing,
        track: tTrackPlayback,
        position: Duration(seconds: 45),
        duration: Duration(seconds: 180),
      );

      final notifier = MockAudioPlayerNotifier(state);
      when(() => notifier.togglePlayPause()).thenAnswer((_) async {});

      await tester.pumpWidget(createWidgetUnderTest(state, notifier: notifier));
      await tester.pumpAndSettle();

      final playPauseFinder = find.byType(IconButton).first;
      await tester.tap(playPauseFinder);
      await tester.pump();

      verify(() => notifier.togglePlayPause()).called(1);
    });

    testWidgets('taps close button to stop playback',
        (WidgetTester tester) async {
      const state = PlayerState(
        status: PlayerStatus.playing,
        track: tTrackPlayback,
        position: Duration(seconds: 45),
        duration: Duration(seconds: 180),
      );

      final notifier = MockAudioPlayerNotifier(state);
      when(() => notifier.stop()).thenAnswer((_) async {});

      await tester.pumpWidget(createWidgetUnderTest(state, notifier: notifier));
      await tester.pumpAndSettle();

      final closeFinder = find.byType(IconButton).last;
      await tester.tap(closeFinder);
      await tester.pump();

      verify(() => notifier.stop()).called(1);
    });
  });
}
