import 'package:dio/dio.dart';
import 'package:hums_mobile/core/network/api_client.dart';
import 'package:hums_mobile/core/network/api_endpoints.dart';
import 'package:hums_mobile/features/playlists/data/models/playlist_model.dart';

abstract class PlaylistRemoteDataSource {
  Future<List<PlaylistModel>> listPlaylists({int skip = 0, int limit = 50});
  Future<PlaylistDetailModel> getPlaylistDetails(String playlistId);
  Future<PlaylistModel> createPlaylist({
    required String name,
    String? description,
  });
  Future<PlaylistModel> updatePlaylist(
    String playlistId, {
    String? name,
    String? description,
    bool? isPublic,
  });
  Future<void> deletePlaylist(String playlistId);
  Future<PlaylistModel> uploadCover(String playlistId, String filePath);
  Future<PlaylistModel> removeCover(String playlistId);
  Future<PlaylistDetailModel> addTrack(String playlistId, String trackId);
  Future<PlaylistDetailModel> removeTrack(String playlistId, String trackId);
  Future<PlaylistDetailModel> reorderTracks(
    String playlistId,
    List<String> trackIds,
  );
}

class PlaylistRemoteDataSourceImpl implements PlaylistRemoteDataSource {
  final ApiClient _apiClient;

  const PlaylistRemoteDataSourceImpl(this._apiClient);

  @override
  Future<List<PlaylistModel>> listPlaylists({
    int skip = 0,
    int limit = 50,
  }) async {
    final response = await _apiClient.get(
      ApiEndpoints.playlists,
      queryParameters: {
        'skip': skip,
        'limit': limit,
      },
    );
    final json = response.data as Map<String, dynamic>;
    final data = json['data'] as List<dynamic>;
    return data
        .map((p) => PlaylistModel.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<PlaylistDetailModel> getPlaylistDetails(String playlistId) async {
    final response = await _apiClient.get(
      ApiEndpoints.playlistDetails(playlistId),
    );
    final json = response.data as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>;
    return PlaylistDetailModel.fromJson(data);
  }

  @override
  Future<PlaylistModel> createPlaylist({
    required String name,
    String? description,
  }) async {
    final requestData = <String, dynamic>{'name': name};
    if (description != null) {
      requestData['description'] = description;
    }

    final response = await _apiClient.post(
      ApiEndpoints.playlists,
      data: requestData,
    );
    final json = response.data as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>;
    return PlaylistModel.fromJson(data);
  }

  @override
  Future<PlaylistModel> updatePlaylist(
    String playlistId, {
    String? name,
    String? description,
    bool? isPublic,
  }) async {
    final requestData = <String, dynamic>{};
    if (name != null) requestData['name'] = name;
    if (description != null) requestData['description'] = description;
    if (isPublic != null) requestData['is_public'] = isPublic;

    final response = await _apiClient.patch(
      ApiEndpoints.playlistDetails(playlistId),
      data: requestData,
    );
    final json = response.data as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>;
    return PlaylistModel.fromJson(data);
  }

  @override
  Future<void> deletePlaylist(String playlistId) async {
    await _apiClient.delete(ApiEndpoints.playlistDetails(playlistId));
  }

  @override
  Future<PlaylistModel> uploadCover(String playlistId, String filePath) async {
    final fileName = filePath.split('/').last;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        filePath,
        filename: fileName,
      ),
    });

    final response = await _apiClient.post(
      ApiEndpoints.playlistCover(playlistId),
      data: formData,
    );
    final json = response.data as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>;
    return PlaylistModel.fromJson(data);
  }

  @override
  Future<PlaylistModel> removeCover(String playlistId) async {
    final response = await _apiClient.delete(
      ApiEndpoints.playlistCover(playlistId),
    );
    final json = response.data as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>;
    return PlaylistModel.fromJson(data);
  }

  @override
  Future<PlaylistDetailModel> addTrack(
    String playlistId,
    String trackId,
  ) async {
    final response = await _apiClient.post(
      ApiEndpoints.playlistTracks(playlistId),
      data: {'track_id': trackId},
    );
    final json = response.data as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>;
    return PlaylistDetailModel.fromJson(data);
  }

  @override
  Future<PlaylistDetailModel> removeTrack(
    String playlistId,
    String trackId,
  ) async {
    final response = await _apiClient.delete(
      ApiEndpoints.playlistTrack(playlistId, trackId),
    );
    final json = response.data as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>;
    return PlaylistDetailModel.fromJson(data);
  }

  @override
  Future<PlaylistDetailModel> reorderTracks(
    String playlistId,
    List<String> trackIds,
  ) async {
    final response = await _apiClient.patch(
      ApiEndpoints.playlistTracksReorder(playlistId),
      data: {'track_ids': trackIds},
    );
    final json = response.data as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>;
    return PlaylistDetailModel.fromJson(data);
  }
}
