import 'package:hums_mobile/core/network/api_client.dart';
import 'package:hums_mobile/core/network/api_endpoints.dart';
import 'package:hums_mobile/features/recommendations/data/models/recommendation_section_model.dart';

abstract class RecommendationRemoteDataSource {
  Future<List<RecommendationSectionModel>> getRecommendations({
    int limit = 10,
    String? section,
    bool refresh = false,
  });

  Future<void> refreshRecommendations();
}

class RecommendationRemoteDataSourceImpl implements RecommendationRemoteDataSource {
  final ApiClient _apiClient;

  const RecommendationRemoteDataSourceImpl(this._apiClient);

  @override
  Future<List<RecommendationSectionModel>> getRecommendations({
    int limit = 10,
    String? section,
    bool refresh = false,
  }) async {
    final queryParams = <String, dynamic>{
      'limit': limit,
      if (section != null && section.isNotEmpty) 'section': section,
      if (refresh) 'refresh': true,
    };

    final response = await _apiClient.get(
      ApiEndpoints.recommendations,
      queryParameters: queryParams,
    );

    final json = response.data as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>;
    final rawSections = data['sections'] as List<dynamic>? ?? [];

    return rawSections
        .map((s) => RecommendationSectionModel.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> refreshRecommendations() async {
    await _apiClient.post(ApiEndpoints.recommendationsRefresh);
  }
}
