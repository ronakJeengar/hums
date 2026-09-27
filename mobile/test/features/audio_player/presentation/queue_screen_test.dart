import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hums_mobile/features/audio_player/domain/entities/playback_entity.dart';
import 'package:hums_mobile/features/audio_player/domain/entities/player_queue.dart';
import 'package:hums_mobile/features/audio_player/presentation/providers/audio_player_provider.dart';
import 'package:hums_mobile/features/audio_player/presentation/screens/queue_screen.dart';
import 'package:hums_mobile/features/audio_player/presentation/states/player_state.dart';

class MockAudioPlayerNotifier extends StateNotifier<PlayerState>
    with Mock
    implements AudioPlayerNotifier {
  MockAudioPlayerNotifier(super.state);
}

void main() {
  const tTrackPlayback = TrackPlaybackEntity(
    trackId: 'track-active',
    title: 'Active Song',
    artistName: 'Active Artist',
    albumName: 'Active Album',
    genre: 'Pop',
    durationSeconds: 210,
    status: 'READY',
    audio: AudioSourceEntity(
      url: 'https://cdn.hums.app/stream/track-active/audio.mp3',
      format: 'mp3',
      codec: 'mp3',
      bitrateKbps: 192,
      durationSeconds: 210,
      fileSizeBytes: 5000000,
    ),
  );

  final manualItem = QueueItem(
    queueItemId: 'item-manual-1',
    trackId: 'track-manual-1',
    title: 'Manual Added Track',
    artistName: 'Manual Artist',
    albumName: 'Manual Album',
    durationSeconds: 195,
    source: QueueItemSource.manual,
  );

  final upNextItem = QueueItem(
    queueItemId: 'item-upnext-1',
    trackId: 'track-upnext-1',
    title: 'Playlist Up Next Track',
    artistName: 'Playlist Artist',
    albumName: 'Playlist Album',
    durationSeconds: 240,
    source: QueueItemSource.playlist,
  );

  final smartItem = QueueItem(
    queueItemId: 'item-smart-1',
    trackId: 'track-smart-1',
    title: 'Smart Recommendation Track',
    artistName: 'Smart Artist',
    albumName: 'Smart Album',
    durationSeconds: 180,
    source: QueueItemSource.smartQueue,
  );

  Widget createWidgetUnderTest(PlayerState state, {MockAudioPlayerNotifier? notifier}) {
    return ProviderScope(
      overrides: [
        audioPlayerNotifierProvider.overrideWith((ref) {
          return notifier ?? MockAudioPlayerNotifier(state);
        }),
      ],
      child: const MaterialApp(
        home: QueueScreen(),
      ),
    );
  }

  setUpAll(() {
    registerFallbackValue(manualItem);
  });

  group('QueueScreen Widget Tests', () {
    testWidgets('renders empty queue state when no track is active', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(const PlayerState()));
      await tester.pumpAndSettle();

      expect(find.text('Queue & Up Next'), findsOneWidget);
      expect(find.text('Your Queue is Empty'), findsOneWidget);
      expect(
        find.text('Play tracks from playlists, search, recommendations, or your library to populate the queue.'),
        findsOneWidget,
      );
    });

    testWidgets('renders Now Playing, Next In Queue, Up Next, and Smart sections', (tester) async {
      final state = PlayerState(
        status: PlayerStatus.playing,
        track: tTrackPlayback,
        queue: PlayerQueue(
          items: [
            QueueItem(
              trackId: tTrackPlayback.trackId,
              title: tTrackPlayback.title,
              artistName: tTrackPlayback.artistName,
              albumName: tTrackPlayback.albumName,
              durationSeconds: tTrackPlayback.durationSeconds,
            ),
          ],
          currentIndex: 0,
          manualItems: [manualItem],
          upNextItems: [upNextItem],
          smartItems: [smartItem],
        ),
      );

      await tester.pumpWidget(createWidgetUnderTest(state));
      await tester.pumpAndSettle();

      // App bar & actions
      expect(find.text('Queue & Up Next'), findsOneWidget);
      expect(find.text('Clear All'), findsOneWidget);

      // Now Playing card
      expect(find.text('NOW PLAYING'), findsOneWidget);
      expect(find.text('Active Song'), findsOneWidget);
      expect(find.text('Active Artist'), findsOneWidget);

      // Manual Queue
      expect(find.text('Next In Queue'), findsOneWidget);
      expect(find.text('Manual Added Track'), findsOneWidget);

      // Up Next
      expect(find.text('Up Next'), findsOneWidget);
      expect(find.text('Playlist Up Next Track'), findsOneWidget);

      // Smart Queue
      expect(find.text('Smart Up Next'), findsOneWidget);
      expect(find.text('Smart Recommendation Track'), findsOneWidget);
    });

    testWidgets('shuffle and repeat buttons trigger notifier methods', (tester) async {
      final state = PlayerState(
        status: PlayerStatus.playing,
        track: tTrackPlayback,
        queue: PlayerQueue(
          items: const [],
          currentIndex: 0,
          upNextItems: [upNextItem],
        ),
      );

      final notifier = MockAudioPlayerNotifier(state);
      when(() => notifier.toggleShuffle()).thenAnswer((_) {});
      when(() => notifier.cycleRepeatMode()).thenAnswer((_) {});

      await tester.pumpWidget(createWidgetUnderTest(state, notifier: notifier));
      await tester.pumpAndSettle();

      // Tap Shuffle
      await tester.tap(find.byIcon(Icons.shuffle));
      await tester.pump();
      verify(() => notifier.toggleShuffle()).called(1);

      // Tap Repeat
      await tester.tap(find.byIcon(Icons.repeat));
      await tester.pump();
      verify(() => notifier.cycleRepeatMode()).called(1);
    });

    testWidgets('Clear All button triggers clearAllUpcomingQueue', (tester) async {
      final state = PlayerState(
        status: PlayerStatus.playing,
        track: tTrackPlayback,
        queue: PlayerQueue(
          items: const [],
          currentIndex: 0,
          manualItems: [manualItem],
        ),
      );

      final notifier = MockAudioPlayerNotifier(state);
      when(() => notifier.clearAllUpcomingQueue()).thenAnswer((_) {});

      await tester.pumpWidget(createWidgetUnderTest(state, notifier: notifier));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Clear All'));
      await tester.pump();
      verify(() => notifier.clearAllUpcomingQueue()).called(1);
    });
  });
}
