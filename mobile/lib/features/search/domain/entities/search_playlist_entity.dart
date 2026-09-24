class SearchPlaylistEntity {
  final String id;
  final String ownerId;
  final String name;
  final String? description;
  final String? coverImageKey;
  final String? coverImageUrl;
  final bool isPublic;
  final int trackCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SearchPlaylistEntity({
    required this.id,
    required this.ownerId,
    required this.name,
    this.description,
    this.coverImageKey,
    this.coverImageUrl,
    this.isPublic = false,
    this.trackCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });
}
