import 'package:hums_mobile/features/recommendations/data/datasources/recommendation_remote_data_source.dart';
import 'package:hums_mobile/features/recommendations/domain/entities/recommendation_section_entity.dart';
import 'package:hums_mobile/features/recommendations/domain/repositories/recommendation_repository.dart';

class RecommendationRepositoryImpl implements RecommendationRepository {
  final RecommendationRemoteDataSource _remoteDataSource;

  const RecommendationRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<RecommendationSectionEntity>> getRecommendations({
    int limit = 10,
    String? section,
    bool refresh = false,
  }) async {
    final models = await _remoteDataSource.getRecommendations(
      limit: limit,
      section: section,
      refresh: refresh,
    );
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<void> refreshRecommendations() async {
    await _remoteDataSource.refreshRecommendations();
  }
}
