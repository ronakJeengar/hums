import 'package:hums_mobile/features/search/domain/entities/search_podcast_entity.dart';

class SearchPodcastModel extends SearchPodcastEntity {
  const SearchPodcastModel({
    required super.id,
    required super.title,
    super.description,
    super.host,
    super.coverImageUrl,
    super.episodeCount,
  });

  factory SearchPodcastModel.fromJson(Map<String, dynamic> json) {
    return SearchPodcastModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      host: json['host'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      episodeCount: (json['episode_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'host': host,
      'cover_image_url': coverImageUrl,
      'episode_count': episodeCount,
    };
  }
}
