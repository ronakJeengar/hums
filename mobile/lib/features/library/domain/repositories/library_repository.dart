import 'package:hums_mobile/features/library/domain/entities/like_status_entity.dart';
import 'package:hums_mobile/features/library/domain/entities/liked_track_entity.dart';
import 'package:hums_mobile/features/library/domain/entities/library_summary_entity.dart';

abstract class LibraryRepository {
  /// Likes an audio track idempotently and increments like count.
  Future<LikeStatusEntity> likeTrack(String trackId);

  /// Unlikes an audio track idempotently and decrements like count.
  Future<LikeStatusEntity> unlikeTrack(String trackId);

  /// Retrieves the like status and like count for a track.
  Future<LikeStatusEntity> getLikeStatus(String trackId);

  /// Retrieves a paginated list of user's liked tracks ordered by liked_at DESC.
  Future<List<LikedTrackEntity>> getLikedTracks({int page = 1, int size = 20});

  /// Retrieves high-level personal library counts and recent liked tracks preview.
  Future<LibrarySummaryEntity> getLibrarySummary();
}
