import 'package:hums_mobile/features/search/data/models/search_artist_model.dart';
import 'package:hums_mobile/features/search/data/models/search_playlist_model.dart';
import 'package:hums_mobile/features/search/data/models/search_track_model.dart';
import 'package:hums_mobile/features/search/domain/entities/search_result_entity.dart';

class SearchResultModel extends SearchResultEntity {
  const SearchResultModel({
    required super.query,
    super.category,
    super.totalTracks,
    super.totalArtists,
    super.totalPlaylists,
    super.tracks,
    super.artists,
    super.playlists,
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

    final playlistsList = (json['playlists'] as List<dynamic>?)
            ?.map((e) => SearchPlaylistModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return SearchResultModel(
      query: json['query'] as String? ?? '',
      category: category,
      totalTracks: (json['total_tracks'] as num?)?.toInt() ?? 0,
      totalArtists: (json['total_artists'] as num?)?.toInt() ?? 0,
      totalPlaylists: (json['total_playlists'] as num?)?.toInt() ?? 0,
      tracks: tracksList,
      artists: artistsList,
      playlists: playlistsList,
    );
  }
}
