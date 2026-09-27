import 'package:hums_mobile/features/social/domain/entities/creator_profile_entity.dart';
import 'package:hums_mobile/features/social/domain/entities/follow_status_entity.dart';

abstract class CreatorRepository {
  /// Fetches detailed public creator profile with aggregated content.
  Future<CreatorDetailEntity> getCreatorProfile(String creatorId);

  /// Follows the specified creator atomically.
  Future<FollowStatusEntity> followCreator(String creatorId);

  /// Unfollows the specified creator atomically.
  Future<FollowStatusEntity> unfollowCreator(String creatorId);

  /// Checks the current follow status for a creator.
  Future<FollowStatusEntity> getFollowStatus(String creatorId);

  /// Fetches paginated public followers of a creator.
  Future<List<FollowerUserEntity>> getCreatorFollowers(
    String creatorId, {
    int page = 1,
    int size = 20,
  });

  /// Fetches creators followed by the authenticated user.
  Future<List<CreatorProfileEntity>> getFollowing({
    int page = 1,
    int size = 20,
  });

  /// Lists popular creators for discovery.
  Future<List<CreatorProfileEntity>> getPopularCreators({
    int skip = 0,
    int limit = 20,
  });
}
