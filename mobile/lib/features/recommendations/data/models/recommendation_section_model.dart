import 'package:hums_mobile/features/recommendations/data/models/recommendation_track_model.dart';
import 'package:hums_mobile/features/recommendations/domain/entities/recommendation_section_entity.dart';

class RecommendationSectionModel {
  final String id;
  final String title;
  final String? description;
  final List<RecommendationTrackModel> items;

  const RecommendationSectionModel({
    required this.id,
    required this.title,
    this.description,
    required this.items,
  });

  factory RecommendationSectionModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return RecommendationSectionModel(
      id: json['id'] as String,
      title: (json['title'] as String?) ?? '',
      description: json['description'] as String?,
      items: rawItems
          .map((i) => RecommendationTrackModel.fromJson(i as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'items': items.map((i) => i.toJson()).toList(),
    };
  }

  RecommendationSectionEntity toEntity() {
    return RecommendationSectionEntity(
      id: id,
      title: title,
      description: description,
      items: items.map((i) => i.toEntity()).toList(),
    );
  }
}
