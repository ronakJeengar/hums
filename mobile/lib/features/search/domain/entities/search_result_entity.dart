import 'package:hums_mobile/features/search/domain/entities/search_album_entity.dart';
import 'package:hums_mobile/features/search/domain/entities/search_artist_entity.dart';
import 'package:hums_mobile/features/search/domain/entities/search_episode_entity.dart';
import 'package:hums_mobile/features/search/domain/entities/search_playlist_entity.dart';
import 'package:hums_mobile/features/search/domain/entities/search_podcast_entity.dart';
import 'package:hums_mobile/features/search/domain/entities/search_track_entity.dart';

enum SearchCategory {
  all,
  tracks,
  artists,
  albums,
  playlists,
  podcasts,
  episodes;

  String get apiValue {
    switch (this) {
      case SearchCategory.all:
        return 'all';
      case SearchCategory.tracks:
        return 'tracks';
      case SearchCategory.artists:
        return 'artists';
      case SearchCategory.albums:
        return 'albums';
      case SearchCategory.playlists:
        return 'playlists';
      case SearchCategory.podcasts:
        return 'podcasts';
      case SearchCategory.episodes:
        return 'episodes';
    }
  }

  String get label {
    switch (this) {
      case SearchCategory.all:
        return 'All';
      case SearchCategory.tracks:
        return 'Songs';
      case SearchCategory.artists:
        return 'Artists';
      case SearchCategory.albums:
        return 'Albums';
      case SearchCategory.playlists:
        return 'Playlists';
      case SearchCategory.podcasts:
        return 'Podcasts';
      case SearchCategory.episodes:
        return 'Episodes';
    }
  }
}

class SearchResultEntity {
  final String query;
  final SearchCategory category;
  final int totalTracks;
  final int totalArtists;
  final int totalAlbums;
  final int totalPlaylists;
  final int totalPodcasts;
  final int totalEpisodes;
  final List<SearchTrackEntity> tracks;
  final List<SearchArtistEntity> artists;
  final List<SearchAlbumEntity> albums;
  final List<SearchPlaylistEntity> playlists;
  final List<SearchPodcastEntity> podcasts;
  final List<SearchEpisodeEntity> episodes;

  const SearchResultEntity({
    required this.query,
    this.category = SearchCategory.all,
    this.totalTracks = 0,
    this.totalArtists = 0,
    this.totalAlbums = 0,
    this.totalPlaylists = 0,
    this.totalPodcasts = 0,
    this.totalEpisodes = 0,
    this.tracks = const [],
    this.artists = const [],
    this.albums = const [],
    this.playlists = const [],
    this.podcasts = const [],
    this.episodes = const [],
  });

  bool get isEmpty =>
      tracks.isEmpty &&
      artists.isEmpty &&
      albums.isEmpty &&
      playlists.isEmpty &&
      podcasts.isEmpty &&
      episodes.isEmpty;

  bool get isNotEmpty => !isEmpty;

  static const empty = SearchResultEntity(query: '');
}
