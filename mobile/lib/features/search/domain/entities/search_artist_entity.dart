class SearchArtistEntity {
  final String id;
  final String name;
  final String? username;
  final String? avatarUrl;
  final String? coverImageUrl;
  final String? bio;
  final int trackCount;
  final int followersCount;
  final bool? isFollowing;
  final bool isVerified;

  const SearchArtistEntity({
    required this.id,
    required this.name,
    this.username,
    this.avatarUrl,
    this.coverImageUrl,
    this.bio,
    this.trackCount = 0,
    this.followersCount = 0,
    this.isFollowing,
    this.isVerified = false,
  });
}
