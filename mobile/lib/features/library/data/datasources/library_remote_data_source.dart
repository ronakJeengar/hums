import 'package:hums_mobile/core/network/api_client.dart';
import 'package:hums_mobile/core/network/api_endpoints.dart';
import 'package:hums_mobile/features/library/data/models/like_status_model.dart';
import 'package:hums_mobile/features/library/data/models/liked_track_model.dart';
import 'package:hums_mobile/features/library/data/models/library_summary_model.dart';

abstract class LibraryRemoteDataSource {
  Future<LikeStatusModel> likeTrack(String trackId);
  Future<LikeStatusModel> unlikeTrack(String trackId);
  Future<LikeStatusModel> getLikeStatus(String trackId);
  Future<List<LikedTrackModel>> getLikedTracks({int page = 1, int size = 20});
  Future<LibrarySummaryModel> getLibrarySummary();
}

class LibraryRemoteDataSourceImpl implements LibraryRemoteDataSource {
  final ApiClient _apiClient;

  LibraryRemoteDataSourceImpl(this._apiClient);

  @override
  Future<LikeStatusModel> likeTrack(String trackId) async {
    final response = await _apiClient.post(ApiEndpoints.trackLike(trackId));
    final data = response.data['data'] as Map<String, dynamic>;
    return LikeStatusModel.fromJson(data);
  }

  @override
  Future<LikeStatusModel> unlikeTrack(String trackId) async {
    final response = await _apiClient.delete(ApiEndpoints.trackLike(trackId));
    final data = response.data['data'] as Map<String, dynamic>;
    return LikeStatusModel.fromJson(data);
  }

  @override
  Future<LikeStatusModel> getLikeStatus(String trackId) async {
    final response = await _apiClient.get(ApiEndpoints.trackLikeStatus(trackId));
    final data = response.data['data'] as Map<String, dynamic>;
    return LikeStatusModel.fromJson(data);
  }

  @override
  Future<List<LikedTrackModel>> getLikedTracks({int page = 1, int size = 20}) async {
    final response = await _apiClient.get(
      ApiEndpoints.libraryLikedTracks(page: page, size: size),
    );
    final data = response.data['data'] as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>? ?? [];
    return items
        .map((item) => LikedTrackModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<LibrarySummaryModel> getLibrarySummary() async {
    final response = await _apiClient.get(ApiEndpoints.library);
    final data = response.data['data'] as Map<String, dynamic>;
    return LibrarySummaryModel.fromJson(data);
  }
}
