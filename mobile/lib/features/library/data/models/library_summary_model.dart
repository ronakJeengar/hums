import 'package:hums_mobile/features/library/data/models/liked_track_model.dart';
import 'package:hums_mobile/features/library/domain/entities/library_summary_entity.dart';

class LibrarySummaryModel extends LibrarySummaryEntity {
  const LibrarySummaryModel({
    required super.likedTracksCount,
    required super.playlistsCount,
    required super.followingCreatorsCount,
    super.recentLikedTracks = const [],
  });

  factory LibrarySummaryModel.fromJson(Map<String, dynamic> json) {
    final recentJson = json['recent_liked_tracks'] as List<dynamic>? ?? [];
    final recentTracks = recentJson
        .map((t) => LikedTrackModel.fromJson(t as Map<String, dynamic>))
        .toList();

    return LibrarySummaryModel(
      likedTracksCount: json['liked_tracks_count'] as int? ?? 0,
      playlistsCount: json['playlists_count'] as int? ?? 0,
      followingCreatorsCount: json['following_creators_count'] as int? ?? 0,
      recentLikedTracks: recentTracks,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'liked_tracks_count': likedTracksCount,
      'playlists_count': playlistsCount,
      'following_creators_count': followingCreatorsCount,
      'recent_liked_tracks': recentLikedTracks
          .map((t) => (t as LikedTrackModel).toJson())
          .toList(),
    };
  }
}
