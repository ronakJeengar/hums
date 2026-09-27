import 'package:hums_mobile/features/search/data/models/search_album_model.dart';
import 'package:hums_mobile/features/search/data/models/search_artist_model.dart';
import 'package:hums_mobile/features/search/data/models/search_episode_model.dart';
import 'package:hums_mobile/features/search/data/models/search_playlist_model.dart';
import 'package:hums_mobile/features/search/data/models/search_podcast_model.dart';
import 'package:hums_mobile/features/search/data/models/search_track_model.dart';
import 'package:hums_mobile/features/search/domain/entities/search_result_entity.dart';

class SearchResultModel extends SearchResultEntity {
  const SearchResultModel({
    required super.query,
    super.category,
    super.totalTracks,
    super.totalArtists,
    super.totalAlbums,
    super.totalPlaylists,
    super.totalPodcasts,
    super.totalEpisodes,
    super.tracks,
    super.artists,
    super.albums,
    super.playlists,
    super.podcasts,
    super.episodes,
  });

  factory SearchResultModel.fromJson(
    Map<String, dynamic> json, {
    SearchCategory category = SearchCategory.all,
  }) {
    final tracksList = (json['tracks'] as List<dynamic>?)
            ?.map((e) => SearchTrackModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final artistsList = (json['artists'] as List<dynamic>?)
            ?.map((e) => SearchArtistModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final albumsList = (json['albums'] as List<dynamic>?)
            ?.map((e) => SearchAlbumModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final playlistsList = (json['playlists'] as List<dynamic>?)
            ?.map((e) => SearchPlaylistModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final podcastsList = (json['podcasts'] as List<dynamic>?)
            ?.map((e) => SearchPodcastModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final episodesList = (json['episodes'] as List<dynamic>?)
            ?.map((e) => SearchEpisodeModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return SearchResultModel(
      query: json['query'] as String? ?? '',
      category: category,
      totalTracks: (json['total_tracks'] as num?)?.toInt() ?? 0,
      totalArtists: (json['total_artists'] as num?)?.toInt() ?? 0,
      totalAlbums: (json['total_albums'] as num?)?.toInt() ?? 0,
      totalPlaylists: (json['total_playlists'] as num?)?.toInt() ?? 0,
      totalPodcasts: (json['total_podcasts'] as num?)?.toInt() ?? 0,
      totalEpisodes: (json['total_episodes'] as num?)?.toInt() ?? 0,
      tracks: tracksList,
      artists: artistsList,
      albums: albumsList,
      playlists: playlistsList,
      podcasts: podcastsList,
      episodes: episodesList,
    );
  }
}
