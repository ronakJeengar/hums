import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hums_mobile/core/theme/app_icons.dart';
import 'package:hums_mobile/core/widgets/app_icon.dart';
import 'package:hums_mobile/features/audio_player/domain/entities/playback_entity.dart';
import 'package:hums_mobile/features/audio_player/domain/entities/player_error.dart';
import 'package:hums_mobile/features/audio_player/presentation/providers/audio_player_provider.dart';
import 'package:hums_mobile/features/audio_player/presentation/screens/full_player_screen.dart';
import 'package:hums_mobile/features/audio_player/presentation/states/player_state.dart';

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
    waveformSamples: [0.1, 0.5, 0.8, 0.3],
  );

  Widget createWidgetUnderTest(PlayerState state,
      {MockAudioPlayerNotifier? notifier}) {
    return ProviderScope(
      overrides: [
        audioPlayerNotifierProvider.overrideWith((ref) {
          return notifier ?? MockAudioPlayerNotifier(state);
        }),
      ],
      child: const MaterialApp(
        home: FullPlayerScreen(),
      ),
    );
  }

  group('FullPlayerScreen Widget Tests', () {
    testWidgets('renders empty state when no track is active',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(const PlayerState(status: PlayerStatus.idle)),
      );
      await tester.pumpAndSettle();

      expect(find.text('No track currently playing'), findsOneWidget);
    });

    testWidgets('renders full player controls and metadata',
        (WidgetTester tester) async {
      const state = PlayerState(
        status: PlayerStatus.playing,
        track: tTrackPlayback,
        position: Duration(seconds: 45),
        duration: Duration(seconds: 180),
      );

      await tester.pumpWidget(createWidgetUnderTest(state));
      await tester.pumpAndSettle();

      expect(find.text('NOW PLAYING'), findsOneWidget);
      expect(find.text('Acoustic Groove'), findsOneWidget);
      expect(find.text('Luna Wave'), findsOneWidget);
      expect(find.text('Echoes'), findsOneWidget);
      expect(find.text('Acoustic'), findsOneWidget);
      expect(find.text('00:45'), findsOneWidget);
      expect(find.text('03:00'), findsOneWidget);
      expect(find.text('MP3 · 192 kbps'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('triggers seekBackward10 and seekForward30',
        (WidgetTester tester) async {
      const state = PlayerState(
        status: PlayerStatus.playing,
        track: tTrackPlayback,
        position: Duration(seconds: 45),
        duration: Duration(seconds: 180),
      );

      final notifier = MockAudioPlayerNotifier(state);
      when(() => notifier.seekBackward10()).thenAnswer((_) async {});
      when(() => notifier.seekForward30()).thenAnswer((_) async {});

      await tester.pumpWidget(createWidgetUnderTest(state, notifier: notifier));
      await tester.pumpAndSettle();

      // Seek backward 10s
      final seekBackwardBtn = find.ancestor(
        of: find.byWidgetPredicate(
          (w) => w is AppIcon && w.icon == AppIcons.seekBackward10,
        ),
        matching: find.byType(IconButton),
      );
      await tester.tap(seekBackwardBtn);
      await tester.pump();
      verify(() => notifier.seekBackward10()).called(1);

      // Seek forward 30s
      final seekForwardBtn = find.ancestor(
        of: find.byWidgetPredicate(
          (w) => w is AppIcon && w.icon == AppIcons.seekForward30,
        ),
        matching: find.byType(IconButton),
      );
      await tester.tap(seekForwardBtn);
      await tester.pump();
      verify(() => notifier.seekForward30()).called(1);
    });

    testWidgets('renders error banner and retry button when error occurs',
        (WidgetTester tester) async {
      const state = PlayerState(
        status: PlayerStatus.error,
        track: tTrackPlayback,
        position: Duration.zero,
        duration: Duration(seconds: 180),
        error: PlayerError(
          type: PlayerErrorType.networkError,
          message: 'Failed to stream audio chunk',
        ),
      );

      final notifier = MockAudioPlayerNotifier(state);
      when(() => notifier.retry()).thenAnswer((_) async {});

      await tester.pumpWidget(createWidgetUnderTest(state, notifier: notifier));
      await tester.pumpAndSettle();

      expect(find.text('Failed to stream audio chunk'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);

      await tester.tap(find.text('Try Again'));
      await tester.pump();
      verify(() => notifier.retry()).called(1);
    });
  });
}
