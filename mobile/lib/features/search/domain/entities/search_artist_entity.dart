class SearchArtistEntity {
  final String id;
  final String name;
  final String? username;
  final String? avatarUrl;
  final String? bio;
  final int trackCount;

  const SearchArtistEntity({
    required this.id,
    required this.name,
    this.username,
    this.avatarUrl,
    this.bio,
    this.trackCount = 0,
  });
}
