class SearchEpisodeEntity {
  final String id;
  final String? podcastId;
  final String title;
  final String? description;
  final int? durationSeconds;
  final DateTime? publishedAt;
  final String? podcastTitle;

  const SearchEpisodeEntity({
    required this.id,
    this.podcastId,
    required this.title,
    this.description,
    this.durationSeconds,
    this.publishedAt,
    this.podcastTitle,
  });
}
