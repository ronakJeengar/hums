import 'package:hums_mobile/core/network/api_client.dart';
import 'package:hums_mobile/core/network/api_endpoints.dart';
import 'package:hums_mobile/features/downloads/data/models/track_download_model.dart';

/// Remote data source contract for fetching download authorization.
abstract class DownloadRemoteDataSource {
  Future<TrackDownloadModel> getAuthorizedDownload(String trackId);
}

class DownloadRemoteDataSourceImpl implements DownloadRemoteDataSource {
  final ApiClient _apiClient;

  DownloadRemoteDataSourceImpl(this._apiClient);

  @override
  Future<TrackDownloadModel> getAuthorizedDownload(String trackId) async {
    final response = await _apiClient.get(
      ApiEndpoints.audioTrackDownload(trackId),
    );

    final data = response.data as Map<String, dynamic>;
    final payload = data['data'] as Map<String, dynamic>;
    return TrackDownloadModel.fromJson(payload);
  }
}
