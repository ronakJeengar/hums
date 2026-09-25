class SearchAlbumEntity {
  final String id;
  final String title;
  final String? artistName;
  final int trackCount;
  final String? coverImageKey;
  final String? coverImageUrl;

  const SearchAlbumEntity({
    required this.id,
    required this.title,
    this.artistName,
    this.trackCount = 0,
    this.coverImageKey,
    this.coverImageUrl,
  });
}
