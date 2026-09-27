import 'package:hums_mobile/core/network/api_client.dart';
import 'package:hums_mobile/core/network/api_endpoints.dart';
import 'package:hums_mobile/features/history/data/models/listening_history_model.dart';
import 'package:hums_mobile/features/history/data/models/playback_event_model.dart';
import 'package:hums_mobile/features/history/data/models/playback_progress_model.dart';

abstract class HistoryRemoteDataSource {
  Future<List<ListeningHistoryItemModel>> getHistory({
    int skip = 0,
    int limit = 50,
  });

  Future<PlaybackProgressModel?> getProgress(String trackId);

  Future<Map<String, PlaybackProgressModel>> getBatchProgress(
    List<String> trackIds,
  );

  Future<PlaybackProgressModel> updateProgress(
    String trackId, {
    required int positionMs,
    required int durationMs,
    bool? completed,
  });

  Future<void> recordEvent(PlaybackEventModel event);

  Future<void> recordBatchEvents(List<PlaybackEventModel> events);

  Future<void> deleteHistoryItem(String trackId);

  Future<void> clearHistory();
}

class HistoryRemoteDataSourceImpl implements HistoryRemoteDataSource {
  final ApiClient _apiClient;

  HistoryRemoteDataSourceImpl(this._apiClient);

  @override
  Future<List<ListeningHistoryItemModel>> getHistory({
    int skip = 0,
    int limit = 50,
  }) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.playbackHistory,
      queryParameters: {'skip': skip, 'limit': limit},
    );

    final data = response.data;
    if (data == null || data['items'] == null) {
      return [];
    }

    final rawList = data['items'] as List<dynamic>;
    return rawList
        .map((item) =>
            ListeningHistoryItemModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<PlaybackProgressModel?> getProgress(String trackId) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.playbackProgress(trackId),
    );
    if (response.data == null) return null;
    return PlaybackProgressModel.fromJson(response.data!);
  }

  @override
  Future<Map<String, PlaybackProgressModel>> getBatchProgress(
    List<String> trackIds,
  ) async {
    if (trackIds.isEmpty) return {};
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.playbackBatchProgress(trackIds),
    );
    final data = response.data;
    if (data == null || data['items'] == null) return {};

    final rawList = data['items'] as List<dynamic>;
    final map = <String, PlaybackProgressModel>{};
    for (final raw in rawList) {
      final model =
          PlaybackProgressModel.fromJson(raw as Map<String, dynamic>);
      map[model.trackId] = model;
    }
    return map;
  }

  @override
  Future<PlaybackProgressModel> updateProgress(
    String trackId, {
    required int positionMs,
    required int durationMs,
    bool? completed,
  }) async {
    final payload = {
      'position_ms': positionMs,
      'duration_ms': durationMs,
      'completed': ?completed,
    };
    final response = await _apiClient.put<Map<String, dynamic>>(
      ApiEndpoints.playbackProgress(trackId),
      data: payload,
    );
    return PlaybackProgressModel.fromJson(response.data!);
  }

  @override
  Future<void> recordEvent(PlaybackEventModel event) async {
    await _apiClient.post(
      ApiEndpoints.playbackEvents,
      data: event.toJson(),
    );
  }

  @override
  Future<void> recordBatchEvents(List<PlaybackEventModel> events) async {
    if (events.isEmpty) return;
    await _apiClient.post(
      ApiEndpoints.playbackEvents,
      data: {
        'events': events.map((e) => e.toJson()).toList(),
      },
    );
  }

  @override
  Future<void> deleteHistoryItem(String trackId) async {
    await _apiClient.delete(
      ApiEndpoints.playbackHistoryItem(trackId),
    );
  }

  @override
  Future<void> clearHistory() async {
    await _apiClient.delete(
      ApiEndpoints.playbackHistory,
    );
  }
}
