import 'package:hums_mobile/features/library/domain/entities/liked_track_entity.dart';

class LibrarySummaryEntity {
  final int likedTracksCount;
  final int playlistsCount;
  final int followingCreatorsCount;
  final List<LikedTrackEntity> recentLikedTracks;

  const LibrarySummaryEntity({
    required this.likedTracksCount,
    required this.playlistsCount,
    required this.followingCreatorsCount,
    this.recentLikedTracks = const [],
  });
}
