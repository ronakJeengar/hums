import 'package:hums_mobile/features/recommendations/domain/entities/recommendation_track_entity.dart';

class RecommendationSectionEntity {
  final String id;
  final String title;
  final String? description;
  final List<RecommendationTrackEntity> items;

  const RecommendationSectionEntity({
    required this.id,
    required this.title,
    this.description,
    required this.items,
  });

  bool get hasItems => items.isNotEmpty;
}
