class SearchPodcastEntity {
  final String id;
  final String title;
  final String? description;
  final String? host;
  final String? coverImageUrl;
  final int episodeCount;

  const SearchPodcastEntity({
    required this.id,
    required this.title,
    this.description,
    this.host,
    this.coverImageUrl,
    this.episodeCount = 0,
  });
}
