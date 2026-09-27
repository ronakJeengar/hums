import 'package:hums_mobile/features/social/domain/entities/follow_status_entity.dart';

class FollowStatusModel extends FollowStatusEntity {
  const FollowStatusModel({
    required super.creatorId,
    required super.isFollowing,
    required super.followersCount,
  });

  factory FollowStatusModel.fromJson(Map<String, dynamic> json) {
    return FollowStatusModel(
      creatorId: json['creator_id'] as String,
      isFollowing: (json['is_following'] as bool?) ?? false,
      followersCount: (json['followers_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'creator_id': creatorId,
      'is_following': isFollowing,
      'followers_count': followersCount,
    };
  }
}

class FollowerUserModel extends FollowerUserEntity {
  const FollowerUserModel({
    required super.id,
    required super.name,
    super.username,
    super.avatarUrl,
    required super.followedAt,
  });

  factory FollowerUserModel.fromJson(Map<String, dynamic> json) {
    return FollowerUserModel(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? 'User',
      username: json['username'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      followedAt: json['followed_at'] != null
          ? DateTime.parse(json['followed_at'] as String)
          : DateTime.now(),
    );
  }
}
