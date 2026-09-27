class FollowStatusEntity {
  final String creatorId;
  final bool isFollowing;
  final int followersCount;

  const FollowStatusEntity({
    required this.creatorId,
    required this.isFollowing,
    required this.followersCount,
  });
}

class FollowerUserEntity {
  final String id;
  final String name;
  final String? username;
  final String? avatarUrl;
  final DateTime followedAt;

  const FollowerUserEntity({
    required this.id,
    required this.name,
    this.username,
    this.avatarUrl,
    required this.followedAt,
  });
}
