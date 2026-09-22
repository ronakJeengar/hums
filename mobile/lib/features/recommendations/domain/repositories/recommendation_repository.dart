import 'package:hums_mobile/features/recommendations/domain/entities/recommendation_section_entity.dart';

abstract class RecommendationRepository {
  Future<List<RecommendationSectionEntity>> getRecommendations({
    int limit = 10,
    String? section,
    bool refresh = false,
  });

  Future<void> refreshRecommendations();
}
