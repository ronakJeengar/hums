import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hums_mobile/core/theme/app_theme.dart';
import 'package:hums_mobile/features/search/domain/entities/search_artist_entity.dart';
import 'package:hums_mobile/features/search/domain/entities/search_playlist_entity.dart';
import 'package:hums_mobile/features/search/domain/entities/search_result_entity.dart';
import 'package:hums_mobile/features/search/domain/entities/search_track_entity.dart';
import 'package:hums_mobile/features/search/domain/repositories/search_repository.dart';
import 'package:hums_mobile/features/search/presentation/providers/search_provider.dart';
import 'package:hums_mobile/features/search/presentation/screens/search_screen.dart';
import 'package:hums_mobile/features/search/presentation/states/search_state.dart';

class _MockSearchRepository implements SearchRepository {
  final SearchResultEntity Function() _resultBuilder;

  _MockSearchRepository(this._resultBuilder);

  @override
  Future<SearchResultEntity> search({
    required String query,
    SearchCategory category = SearchCategory.all,
    int limit = 20,
    int skip = 0,
  }) async {
    return _resultBuilder();
  }
}

class SearchPreviewWrapper extends StatelessWidget {
  final SearchState initialState;

  const SearchPreviewWrapper({
    super.key,
    required this.initialState,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: SizedBox(
        width: 390,
        height: 844,
        child: ProviderScope(
          overrides: [
            searchRepositoryProvider.overrideWithValue(
              _MockSearchRepository(() => initialState.results),
            ),
            searchNotifierProvider.overrideWith(
              (ref) => _PresetSearchNotifier(initialState),
            ),
          ],
          child: const SearchScreen(),
        ),
      ),
    );
  }
}

class _PresetSearchNotifier extends SearchNotifier {
  _PresetSearchNotifier(SearchState preset)
      : super(_MockSearchRepository(() => preset.results)) {
    state = preset;
  }
}

// Sample Mock Data
final _sampleTracks = [
  SearchTrackEntity(
    id: 'track-1',
    ownerId: 'user-1',
    title: 'Kesariya Tera Ishq Hai Piya',
    artistName: 'Arijit Singh',
    albumName: 'Brahmastra',
    genre: 'Romantic',
    durationSeconds: 268,
    status: 'READY',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
  SearchTrackEntity(
    id: 'track-2',
    ownerId: 'user-1',
    title: 'Apna Bana Le',
    artistName: 'Arijit Singh, Sachin-Jigar',
    albumName: 'Bhediya',
    genre: 'Soulful',
    durationSeconds: 245,
    status: 'READY',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
];

final _sampleArtists = [
  const SearchArtistEntity(
    id: 'artist-1',
    name: 'Arijit Singh',
    trackCount: 14,
    bio: 'Playback singer and composer',
  ),
  const SearchArtistEntity(
    id: 'artist-2',
    name: 'Sachin-Jigar',
    trackCount: 8,
    bio: 'Music director duo',
  ),
];

final _samplePlaylists = [
  SearchPlaylistEntity(
    id: 'playlist-1',
    ownerId: 'user-1',
    name: 'Best of Arijit Singh',
    description: 'Soul-stirring romantic hits',
    isPublic: true,
    trackCount: 25,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
];

/// 1. Initial Empty / Explore Prompt Preview
Widget searchInitialPreview() {
  return const SearchPreviewWrapper(
    initialState: SearchState(
      status: SearchStatus.initial,
      query: '',
    ),
  );
}

/// 2. Loading State Preview
Widget searchLoadingPreview() {
  return const SearchPreviewWrapper(
    initialState: SearchState(
      status: SearchStatus.loading,
      query: 'Arijit',
    ),
  );
}

/// 3. Populated Multi-Entity Results Preview
Widget searchResultsPreview() {
  return SearchPreviewWrapper(
    initialState: SearchState(
      status: SearchStatus.loaded,
      query: 'Arijit',
      category: SearchCategory.all,
      results: SearchResultEntity(
        query: 'Arijit',
        category: SearchCategory.all,
        totalTracks: 2,
        totalArtists: 2,
        totalPlaylists: 1,
        tracks: _sampleTracks,
        artists: _sampleArtists,
        playlists: _samplePlaylists,
      ),
    ),
  );
}

/// 4. Category Filtered (Tracks Only) Preview
Widget searchTracksFilteredPreview() {
  return SearchPreviewWrapper(
    initialState: SearchState(
      status: SearchStatus.loaded,
      query: 'Arijit',
      category: SearchCategory.tracks,
      results: SearchResultEntity(
        query: 'Arijit',
        category: SearchCategory.tracks,
        totalTracks: 2,
        tracks: _sampleTracks,
      ),
    ),
  );
}

/// 5. No Results Found Preview
Widget searchEmptyPreview() {
  return const SearchPreviewWrapper(
    initialState: SearchState(
      status: SearchStatus.loaded,
      query: 'Zzzqqq999',
      category: SearchCategory.all,
      results: SearchResultEntity(
        query: 'Zzzqqq999',
        category: SearchCategory.all,
        totalTracks: 0,
        totalArtists: 0,
        totalPlaylists: 0,
      ),
    ),
  );
}

/// 6. Error State Preview
Widget searchErrorPreview() {
  return const SearchPreviewWrapper(
    initialState: SearchState(
      status: SearchStatus.error,
      query: 'Offline Query',
      errorMessage: 'Network connection lost. Please check your internet connection.',
    ),
  );
}
