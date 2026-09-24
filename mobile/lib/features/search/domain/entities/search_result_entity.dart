import 'package:hums_mobile/features/search/domain/entities/search_artist_entity.dart';
import 'package:hums_mobile/features/search/domain/entities/search_playlist_entity.dart';
import 'package:hums_mobile/features/search/domain/entities/search_track_entity.dart';

enum SearchCategory {
  all,
  tracks,
  artists,
  playlists;

  String get apiValue {
    switch (this) {
      case SearchCategory.all:
        return 'all';
      case SearchCategory.tracks:
        return 'tracks';
      case SearchCategory.artists:
        return 'artists';
      case SearchCategory.playlists:
        return 'playlists';
    }
  }

  String get label {
    switch (this) {
      case SearchCategory.all:
        return 'All';
      case SearchCategory.tracks:
        return 'Tracks';
      case SearchCategory.artists:
        return 'Artists';
      case SearchCategory.playlists:
        return 'Playlists';
    }
  }
}

class SearchResultEntity {
  final String query;
  final SearchCategory category;
  final int totalTracks;
  final int totalArtists;
  final int totalPlaylists;
  final List<SearchTrackEntity> tracks;
  final List<SearchArtistEntity> artists;
  final List<SearchPlaylistEntity> playlists;

  const SearchResultEntity({
    required this.query,
    this.category = SearchCategory.all,
    this.totalTracks = 0,
    this.totalArtists = 0,
    this.totalPlaylists = 0,
    this.tracks = const [],
    this.artists = const [],
    this.playlists = const [],
  });

  bool get isEmpty =>
      tracks.isEmpty && artists.isEmpty && playlists.isEmpty;

  bool get isNotEmpty => !isEmpty;

  static const empty = SearchResultEntity(query: '');
}
