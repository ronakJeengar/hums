import 'package:hums_mobile/features/social/data/datasources/creator_remote_data_source.dart';
import 'package:hums_mobile/features/social/domain/entities/creator_profile_entity.dart';
import 'package:hums_mobile/features/social/domain/entities/follow_status_entity.dart';
import 'package:hums_mobile/features/social/domain/repositories/creator_repository.dart';

class CreatorRepositoryImpl implements CreatorRepository {
  final CreatorRemoteDataSource _remoteDataSource;

  const CreatorRepositoryImpl(this._remoteDataSource);

  @override
  Future<CreatorDetailEntity> getCreatorProfile(String creatorId) {
    return _remoteDataSource.getCreatorProfile(creatorId);
  }

  @override
  Future<FollowStatusEntity> followCreator(String creatorId) {
    return _remoteDataSource.followCreator(creatorId);
  }

  @override
  Future<FollowStatusEntity> unfollowCreator(String creatorId) {
    return _remoteDataSource.unfollowCreator(creatorId);
  }

  @override
  Future<FollowStatusEntity> getFollowStatus(String creatorId) {
    return _remoteDataSource.getFollowStatus(creatorId);
  }

  @override
  Future<List<FollowerUserEntity>> getCreatorFollowers(String creatorId, {int page = 1, int size = 20}) {
    return _remoteDataSource.getCreatorFollowers(creatorId, page: page, size: size);
  }

  @override
  Future<List<CreatorProfileEntity>> getFollowing({int page = 1, int size = 20}) {
    return _remoteDataSource.getFollowing(page: page, size: size);
  }

  @override
  Future<List<CreatorProfileEntity>> getPopularCreators({int skip = 0, int limit = 20}) {
    return _remoteDataSource.getPopularCreators(skip: skip, limit: limit);
  }
}
