import 'package:hums_mobile/features/search/domain/entities/search_episode_entity.dart';

class SearchEpisodeModel extends SearchEpisodeEntity {
  const SearchEpisodeModel({
    required super.id,
    super.podcastId,
    required super.title,
    super.description,
    super.durationSeconds,
    super.publishedAt,
    super.podcastTitle,
  });

  factory SearchEpisodeModel.fromJson(Map<String, dynamic> json) {
    return SearchEpisodeModel(
      id: json['id'] as String,
      podcastId: json['podcast_id'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
      publishedAt: json['published_at'] != null
          ? DateTime.tryParse(json['published_at'] as String)
          : null,
      podcastTitle: json['podcast_title'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'podcast_id': podcastId,
      'title': title,
      'description': description,
      'duration_seconds': durationSeconds,
      'published_at': publishedAt?.toIso8601String(),
      'podcast_title': podcastTitle,
    };
  }
}
