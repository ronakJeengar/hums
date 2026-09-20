import 'package:dio/dio.dart';
import 'package:hums_mobile/core/network/api_client.dart';
import 'package:hums_mobile/core/network/api_endpoints.dart';
import 'package:hums_mobile/features/audio/data/models/track_model.dart';

abstract class AudioRemoteDataSource {
  Future<TrackModel> uploadAudio({
    required String filePath,
    required String title,
    String? description,
    String? artistName,
    String? albumName,
    String? genre,
    void Function(double progress)? onProgress,
  });

  Future<List<TrackModel>> listTracks({int skip = 0, int limit = 50});

  Future<TrackModel> getTrack(String trackId);

  Future<TrackStatusModel> getTrackStatus(String trackId);
}

class AudioRemoteDataSourceImpl implements AudioRemoteDataSource {
  final ApiClient _apiClient;

  const AudioRemoteDataSourceImpl(this._apiClient);

  @override
  Future<TrackModel> uploadAudio({
    required String filePath,
    required String title,
    String? description,
    String? artistName,
    String? albumName,
    String? genre,
    void Function(double progress)? onProgress,
  }) async {
    final fileName = filePath.split('/').last;
    final map = <String, dynamic>{
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
      'title': title,
    };
    if (description != null && description.isNotEmpty) {
      map['description'] = description;
    }
    if (artistName != null && artistName.isNotEmpty) {
      map['artist_name'] = artistName;
    }
    if (albumName != null && albumName.isNotEmpty) {
      map['album_name'] = albumName;
    }
    if (genre != null && genre.isNotEmpty) {
      map['genre'] = genre;
    }

    final formData = FormData.fromMap(map);

    final response = await _apiClient.post(
      ApiEndpoints.audioUpload,
      data: formData,
      onSendProgress: (sent, total) {
        if (total > 0 && onProgress != null) {
          onProgress(sent / total);
        }
      },
    );

    final json = response.data as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>;
    return TrackModel.fromJson(data);
  }

  @override
  Future<List<TrackModel>> listTracks({int skip = 0, int limit = 50}) async {
    final response = await _apiClient.get(
      ApiEndpoints.audioTracks,
      queryParameters: {'skip': skip, 'limit': limit},
    );
    final json = response.data as Map<String, dynamic>;
    final list = json['data'] as List<dynamic>? ?? [];
    return list
        .map((item) => TrackModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<TrackModel> getTrack(String trackId) async {
    final response = await _apiClient.get(ApiEndpoints.audioTrackDetails(trackId));
    final json = response.data as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>;
    return TrackModel.fromJson(data);
  }

  @override
  Future<TrackStatusModel> getTrackStatus(String trackId) async {
    final response = await _apiClient.get(ApiEndpoints.audioTrackStatus(trackId));
    final json = response.data as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>;
    return TrackStatusModel.fromJson(data);
  }
}
