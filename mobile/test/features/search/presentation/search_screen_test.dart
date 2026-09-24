import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hums_mobile/features/audio_player/presentation/providers/audio_player_provider.dart';
import 'package:hums_mobile/features/audio_player/presentation/states/player_state.dart';
import 'package:hums_mobile/features/search/domain/entities/search_artist_entity.dart';
import 'package:hums_mobile/features/search/domain/entities/search_playlist_entity.dart';
import 'package:hums_mobile/features/search/domain/entities/search_result_entity.dart';
import 'package:hums_mobile/features/search/domain/entities/search_track_entity.dart';
import 'package:hums_mobile/features/search/domain/repositories/search_repository.dart';
import 'package:hums_mobile/features/search/presentation/providers/search_provider.dart';
import 'package:hums_mobile/features/search/presentation/screens/search_screen.dart';
import 'package:hums_mobile/features/search/presentation/states/search_state.dart';

class MockAudioPlayerNotifier extends StateNotifier<PlayerState>
    with Mock
    implements AudioPlayerNotifier {
  MockAudioPlayerNotifier(super.state);
}

class MockSearchRepository extends Mock implements SearchRepository {}

class FakeSearchNotifier extends SearchNotifier {
  FakeSearchNotifier(super.repository, {SearchState? initial}) {
    if (initial != null) {
      state = initial;
    }
  }

  void setStateForTest(SearchState newState) {
    state = newState;
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(SearchCategory.all);
  });

  late MockAudioPlayerNotifier mockPlayerNotifier;
  late MockSearchRepository mockSearchRepo;

  final sampleTrack = SearchTrackEntity(
    id: 'track-101',
    ownerId: 'user-1',
    title: 'Raabta Acoustic',
    artistName: 'Arijit Singh',
    albumName: 'Agent Vinod',
    genre: 'Romantic',
    durationSeconds: 243,
    status: 'READY',
    createdAt: DateTime(2026, 9, 20),
    updatedAt: DateTime(2026, 9, 20),
  );

  final sampleArtist = const SearchArtistEntity(
    id: 'artist-201',
    name: 'Arijit Singh',
    trackCount: 15,
    bio: 'Playback singer',
  );

  final samplePlaylist = SearchPlaylistEntity(
    id: 'playlist-301',
    ownerId: 'user-1',
    name: 'Soulful Evenings',
    description: 'Acoustic evening tracks',
    isPublic: true,
    trackCount: 8,
    createdAt: DateTime(2026, 9, 20),
    updatedAt: DateTime(2026, 9, 20),
  );

  setUp(() {
    mockPlayerNotifier = MockAudioPlayerNotifier(const PlayerState());
    mockSearchRepo = MockSearchRepository();
  });

  Widget createWidgetUnderTest(FakeSearchNotifier notifier) {
    return ProviderScope(
      overrides: [
        audioPlayerNotifierProvider.overrideWith((ref) => mockPlayerNotifier),
        searchRepositoryProvider.overrideWithValue(mockSearchRepo),
        searchNotifierProvider.overrideWith((ref) => notifier),
      ],
      child: const MaterialApp(
        home: SearchScreen(),
      ),
    );
  }

  group('SearchScreen Widget Tests', () {
    testWidgets('renders initial explore state with prompt and category chips',
        (WidgetTester tester) async {
      final notifier = FakeSearchNotifier(mockSearchRepo);

      await tester.pumpWidget(createWidgetUnderTest(notifier));
      await tester.pumpAndSettle();

      expect(find.text('Explore the Catalog'), findsOneWidget);
      expect(
        find.text('Search for songs, creators, playlists, and genres across Hums.'),
        findsOneWidget,
      );
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Tracks'), findsOneWidget);
      expect(find.text('Artists'), findsOneWidget);
      expect(find.text('Playlists'), findsOneWidget);
    });

    testWidgets('renders loading indicator when search is loading',
        (WidgetTester tester) async {
      final notifier = FakeSearchNotifier(
        mockSearchRepo,
        initial: const SearchState(
          status: SearchStatus.loading,
          query: 'Arijit',
        ),
      );

      await tester.pumpWidget(createWidgetUnderTest(notifier));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Searching Hums...'), findsOneWidget);
    });

    testWidgets('renders error message and taps retry button',
        (WidgetTester tester) async {
      when(() => mockSearchRepo.search(
            query: any(named: 'query'),
            category: any(named: 'category'),
          )).thenAnswer((_) async => const SearchResultEntity(query: 'Arijit'));

      final notifier = FakeSearchNotifier(
        mockSearchRepo,
        initial: const SearchState(
          status: SearchStatus.error,
          query: 'Arijit',
          errorMessage: 'Server timeout during query',
        ),
      );

      await tester.pumpWidget(createWidgetUnderTest(notifier));
      await tester.pumpAndSettle();

      expect(find.text('Search Failed'), findsOneWidget);
      expect(find.text('Server timeout during query'), findsOneWidget);

      final retryButton = find.text('Retry');
      expect(retryButton, findsOneWidget);
      await tester.tap(retryButton);
      await tester.pump();

      verify(() => mockSearchRepo.search(
            query: 'Arijit',
            category: any(named: 'category'),
          )).called(1);
    });

    testWidgets('renders empty results message when no matches found',
        (WidgetTester tester) async {
      final notifier = FakeSearchNotifier(
        mockSearchRepo,
        initial: const SearchState(
          status: SearchStatus.loaded,
          query: 'NonExistentTitle',
          results: SearchResultEntity(query: 'NonExistentTitle'),
        ),
      );

      await tester.pumpWidget(createWidgetUnderTest(notifier));
      await tester.pumpAndSettle();

      expect(find.text('No Results Found'), findsOneWidget);
      expect(
        find.text('No matches found for "NonExistentTitle". Try a different keyword or check spelling.'),
        findsOneWidget,
      );
    });

    testWidgets('renders categorized search results and triggers playback on track tap',
        (WidgetTester tester) async {
      when(() => mockPlayerNotifier.playTrack('track-101'))
          .thenAnswer((_) async {});

      final notifier = FakeSearchNotifier(
        mockSearchRepo,
        initial: SearchState(
          status: SearchStatus.loaded,
          query: 'Arijit',
          category: SearchCategory.all,
          results: SearchResultEntity(
            query: 'Arijit',
            totalTracks: 1,
            totalArtists: 1,
            totalPlaylists: 1,
            tracks: [sampleTrack],
            artists: [sampleArtist],
            playlists: [samplePlaylist],
          ),
        ),
      );

      await tester.pumpWidget(createWidgetUnderTest(notifier));
      await tester.pumpAndSettle();

      // Verify Track item rendered
      expect(find.text('Raabta Acoustic'), findsOneWidget);
      expect(find.text('04:03'), findsOneWidget);

      // Verify Artist item rendered
      expect(find.text('Arijit Singh'), findsWidgets);
      expect(find.text('15 tracks'), findsOneWidget);

      // Verify Playlist item rendered
      expect(find.text('Soulful Evenings'), findsOneWidget);
      expect(find.text('8 tracks'), findsOneWidget);

      // Tap on Track item to trigger playback
      await tester.tap(find.text('Raabta Acoustic'));
      await tester.pump();

      verify(() => mockPlayerNotifier.playTrack('track-101')).called(1);
    });

    testWidgets('selecting category chip updates category on notifier',
        (WidgetTester tester) async {
      when(() => mockSearchRepo.search(
            query: any(named: 'query'),
            category: any(named: 'category'),
          )).thenAnswer((_) async => const SearchResultEntity(query: 'Arijit'));

      final notifier = FakeSearchNotifier(
        mockSearchRepo,
        initial: const SearchState(
          status: SearchStatus.loaded,
          query: 'Arijit',
          category: SearchCategory.all,
        ),
      );

      await tester.pumpWidget(createWidgetUnderTest(notifier));
      await tester.pumpAndSettle();

      // Tap Tracks chip
      await tester.tap(find.text('Tracks'));
      await tester.pump();

      expect(notifier.state.category, SearchCategory.tracks);
    });
  });
}
