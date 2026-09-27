import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hums_mobile/features/audio_player/domain/entities/playback_entity.dart';
import 'package:hums_mobile/features/audio_player/domain/entities/player_queue.dart';
import 'package:hums_mobile/features/audio_player/presentation/providers/audio_player_provider.dart';
import 'package:hums_mobile/features/audio_player/presentation/states/player_state.dart';
import 'package:hums_mobile/features/recommendations/domain/entities/recommendation_section_entity.dart';
import 'package:hums_mobile/features/recommendations/domain/entities/recommendation_track_entity.dart';
import 'package:hums_mobile/features/recommendations/presentation/providers/recommendation_provider.dart';
import 'package:hums_mobile/features/recommendations/presentation/states/recommendation_state.dart';
import 'package:hums_mobile/features/recommendations/presentation/widgets/recommendation_section_widget.dart';
import 'package:hums_mobile/features/recommendations/presentation/widgets/recommendation_track_card.dart';
import 'package:hums_mobile/features/recommendations/presentation/widgets/recommendations_view.dart';

class MockAudioPlayerNotifier extends StateNotifier<PlayerState>
    with Mock
    implements AudioPlayerNotifier {
  MockAudioPlayerNotifier(super.state);
}

class MockRecommendationNotifier extends StateNotifier<RecommendationState>
    with Mock
    implements RecommendationNotifier {
  MockRecommendationNotifier(super.state);
}

class FakePlayerQueue extends Fake implements PlayerQueue {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakePlayerQueue());
  });

  const tTrack1 = RecommendationTrackEntity(
    id: 'track-1',
    title: 'Neon Skyline',
    artistName: 'Synth Boy',
    albumName: 'Night City',
    genre: 'Synthwave',
    durationSeconds: 210,
    status: 'READY',
  );

  const tTrack2 = RecommendationTrackEntity(
    id: 'track-2',
    title: 'Deep Focus',
    artistName: 'Chill Architect',
    genre: 'Ambient',
    durationSeconds: 185,
    status: 'READY',
  );

  const tSection = RecommendationSectionEntity(
    id: 'for-you',
    title: 'Recommended For You',
    description: 'Based on your listening taste',
    items: [tTrack1, tTrack2],
  );

  group('RecommendationTrackCard Widget Tests', () {
    testWidgets('renders track title, artist, genre, and duration',
        (WidgetTester tester) async {
      final mockPlayerNotifier = MockAudioPlayerNotifier(const PlayerState());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioPlayerNotifierProvider.overrideWith((ref) => mockPlayerNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: RecommendationTrackCard(track: tTrack1),
            ),
          ),
        ),
      );

      expect(find.text('Neon Skyline'), findsOneWidget);
      expect(find.text('Synth Boy'), findsOneWidget);
      expect(find.text('Synthwave'), findsOneWidget);
      expect(find.text('03:30'), findsOneWidget);
    });

    testWidgets('tapping card triggers playTrack on audio player notifier',
        (WidgetTester tester) async {
      final mockPlayerNotifier = MockAudioPlayerNotifier(const PlayerState());
      when(() => mockPlayerNotifier.playTrack('track-1'))
          .thenAnswer((_) async {});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioPlayerNotifierProvider.overrideWith((ref) => mockPlayerNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: RecommendationTrackCard(track: tTrack1),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(RecommendationTrackCard));
      verify(() => mockPlayerNotifier.playTrack('track-1')).called(1);
    });

    testWidgets('custom onTap callback is called when provided',
        (WidgetTester tester) async {
      bool tapped = false;
      final mockPlayerNotifier = MockAudioPlayerNotifier(const PlayerState());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioPlayerNotifierProvider.overrideWith((ref) => mockPlayerNotifier),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: RecommendationTrackCard(
                track: tTrack1,
                onTap: () {
                  tapped = true;
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(RecommendationTrackCard));
      expect(tapped, isTrue);
      verifyNever(() => mockPlayerNotifier.playTrack(any()));
    });

    testWidgets('shows pause icon when track is currently playing',
        (WidgetTester tester) async {
      const playingState = PlayerState(
        status: PlayerStatus.playing,
        track: TrackPlaybackEntity(
          trackId: 'track-1',
          title: 'Neon Skyline',
          status: 'READY',
          audio: AudioSourceEntity(
            url: 'https://cdn.hums.app/stream.mp3',
            format: 'mp3',
            codec: 'mp3',
            bitrateKbps: 192,
            durationSeconds: 210,
            fileSizeBytes: 5000000,
          ),
        ),
      );
      final mockPlayerNotifier = MockAudioPlayerNotifier(playingState);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioPlayerNotifierProvider.overrideWith((ref) => mockPlayerNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: RecommendationTrackCard(track: tTrack1),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    });
  });

  group('RecommendationSectionWidget Widget Tests', () {
    testWidgets('renders section header, description, and track cards',
        (WidgetTester tester) async {
      final mockPlayerNotifier = MockAudioPlayerNotifier(const PlayerState());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioPlayerNotifierProvider.overrideWith((ref) => mockPlayerNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: RecommendationSectionWidget(section: tSection),
            ),
          ),
        ),
      );

      expect(find.text('Recommended For You'), findsOneWidget);
      expect(find.text('Based on your listening taste'), findsOneWidget);
      expect(find.text('Play All'), findsOneWidget);
      expect(find.text('Neon Skyline'), findsOneWidget);
      expect(find.text('Deep Focus'), findsOneWidget);
    });

    testWidgets('tapping Play All calls playQueue with playable tracks',
        (WidgetTester tester) async {
      final mockPlayerNotifier = MockAudioPlayerNotifier(const PlayerState());
      when(() => mockPlayerNotifier.playQueue(any())).thenAnswer((_) async {});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioPlayerNotifierProvider.overrideWith((ref) => mockPlayerNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: RecommendationSectionWidget(section: tSection),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Play All'));
      verify(() => mockPlayerNotifier.playQueue(any())).called(1);
    });

    testWidgets('returns SizedBox.shrink when section items are empty',
        (WidgetTester tester) async {
      const emptySection = RecommendationSectionEntity(
        id: 'empty-sec',
        title: 'Empty',
        items: [],
      );

      final mockPlayerNotifier = MockAudioPlayerNotifier(const PlayerState());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioPlayerNotifierProvider.overrideWith((ref) => mockPlayerNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: RecommendationSectionWidget(section: emptySection),
            ),
          ),
        ),
      );

      expect(find.text('Empty'), findsNothing);
      expect(find.text('Play All'), findsNothing);
    });
  });

  group('RecommendationsView Widget Tests', () {
    testWidgets('shows loading skeleton when state is loading with no sections',
        (WidgetTester tester) async {
      final mockRecNotifier = MockRecommendationNotifier(
        const RecommendationState(status: RecommendationStatus.loading),
      );
      when(() => mockRecNotifier.loadRecommendations()).thenAnswer((_) async {});

      final mockPlayerNotifier = MockAudioPlayerNotifier(const PlayerState());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            recommendationNotifierProvider.overrideWith((ref) => mockRecNotifier),
            audioPlayerNotifierProvider.overrideWith((ref) => mockPlayerNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: RecommendationsView(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(RecommendationSectionWidget), findsNothing);
    });

    testWidgets('shows error state when status is error with no sections',
        (WidgetTester tester) async {
      final mockRecNotifier = MockRecommendationNotifier(
        const RecommendationState(
          status: RecommendationStatus.error,
          errorMessage: 'Unable to reach recommendation service',
        ),
      );
      when(() => mockRecNotifier.loadRecommendations()).thenAnswer((_) async {});
      when(() => mockRecNotifier.loadRecommendations(refresh: true))
          .thenAnswer((_) async {});

      final mockPlayerNotifier = MockAudioPlayerNotifier(const PlayerState());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            recommendationNotifierProvider.overrideWith((ref) => mockRecNotifier),
            audioPlayerNotifierProvider.overrideWith((ref) => mockPlayerNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: RecommendationsView(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Recommendations Unavailable'), findsOneWidget);
      expect(find.text('Unable to reach recommendation service'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      verify(() => mockRecNotifier.loadRecommendations(refresh: true)).called(1);
    });

    testWidgets('shows empty state when state is loaded with no items',
        (WidgetTester tester) async {
      final mockRecNotifier = MockRecommendationNotifier(
        const RecommendationState(
          status: RecommendationStatus.loaded,
          sections: [],
        ),
      );
      when(() => mockRecNotifier.loadRecommendations()).thenAnswer((_) async {});

      final mockPlayerNotifier = MockAudioPlayerNotifier(const PlayerState());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            recommendationNotifierProvider.overrideWith((ref) => mockRecNotifier),
            audioPlayerNotifierProvider.overrideWith((ref) => mockPlayerNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: RecommendationsView(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('No Recommendations Yet'), findsOneWidget);
      expect(find.text('Discover sounds by exploring playlists and uploading your favorite tracks.'), findsOneWidget);
    });

    testWidgets('renders sections when state is loaded with sections',
        (WidgetTester tester) async {
      final mockRecNotifier = MockRecommendationNotifier(
        const RecommendationState(
          status: RecommendationStatus.loaded,
          sections: [tSection],
        ),
      );
      when(() => mockRecNotifier.loadRecommendations()).thenAnswer((_) async {});

      final mockPlayerNotifier = MockAudioPlayerNotifier(const PlayerState());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            recommendationNotifierProvider.overrideWith((ref) => mockRecNotifier),
            audioPlayerNotifierProvider.overrideWith((ref) => mockPlayerNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: RecommendationsView()),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(RecommendationSectionWidget), findsOneWidget);
      expect(find.text('Recommended For You'), findsOneWidget);
      expect(find.text('Neon Skyline'), findsOneWidget);
      expect(find.text('Deep Focus'), findsOneWidget);
    });
  });
}
