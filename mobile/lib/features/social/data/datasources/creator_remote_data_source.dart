import 'package:hums_mobile/core/network/api_client.dart';
import 'package:hums_mobile/core/network/api_endpoints.dart';
import 'package:hums_mobile/features/social/data/models/creator_profile_model.dart';
import 'package:hums_mobile/features/social/data/models/follow_status_model.dart';

abstract class CreatorRemoteDataSource {
  Future<CreatorDetailModel> getCreatorProfile(String creatorId);
  Future<FollowStatusModel> followCreator(String creatorId);
  Future<FollowStatusModel> unfollowCreator(String creatorId);
  Future<FollowStatusModel> getFollowStatus(String creatorId);
  Future<List<FollowerUserModel>> getCreatorFollowers(String creatorId, {int page = 1, int size = 20});
  Future<List<CreatorProfileModel>> getFollowing({int page = 1, int size = 20});
  Future<List<CreatorProfileModel>> getPopularCreators({int skip = 0, int limit = 20});
}

class CreatorRemoteDataSourceImpl implements CreatorRemoteDataSource {
  final ApiClient _apiClient;

  const CreatorRemoteDataSourceImpl(this._apiClient);

  @override
  Future<CreatorDetailModel> getCreatorProfile(String creatorId) async {
    final response = await _apiClient.get(ApiEndpoints.creatorDetails(creatorId));
    final json = response.data as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>;
    return CreatorDetailModel.fromJson(data);
  }

  @override
  Future<FollowStatusModel> followCreator(String creatorId) async {
    final response = await _apiClient.post(ApiEndpoints.creatorFollow(creatorId));
    final json = response.data as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>;
    return FollowStatusModel.fromJson(data);
  }

  @override
  Future<FollowStatusModel> unfollowCreator(String creatorId) async {
    final response = await _apiClient.delete(ApiEndpoints.creatorFollow(creatorId));
    final json = response.data as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>;
    return FollowStatusModel.fromJson(data);
  }

  @override
  Future<FollowStatusModel> getFollowStatus(String creatorId) async {
    final response = await _apiClient.get(ApiEndpoints.creatorFollowStatus(creatorId));
    final json = response.data as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>;
    return FollowStatusModel.fromJson(data);
  }

  @override
  Future<List<FollowerUserModel>> getCreatorFollowers(String creatorId, {int page = 1, int size = 20}) async {
    final response = await _apiClient.get(ApiEndpoints.creatorFollowers(creatorId, page: page, size: size));
    final json = response.data as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>?) ?? [];
    return items.map((i) => FollowerUserModel.fromJson(i as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<CreatorProfileModel>> getFollowing({int page = 1, int size = 20}) async {
    final response = await _apiClient.get(ApiEndpoints.userFollowing(page: page, size: size));
    final json = response.data as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>?) ?? [];
    return items.map((i) => CreatorProfileModel.fromJson(i as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<CreatorProfileModel>> getPopularCreators({int skip = 0, int limit = 20}) async {
    final response = await _apiClient.get(
      ApiEndpoints.creators,
      queryParameters: {'skip': skip, 'limit': limit},
    );
    final json = response.data as Map<String, dynamic>;
    final items = (json['data'] as List<dynamic>?) ?? [];
    return items.map((i) => CreatorProfileModel.fromJson(i as Map<String, dynamic>)).toList();
  }
}
