import 'package:hums_mobile/features/search/domain/entities/search_artist_entity.dart';

class SearchArtistModel extends SearchArtistEntity {
  const SearchArtistModel({
    required super.id,
    required super.name,
    super.username,
    super.avatarUrl,
    super.coverImageUrl,
    super.bio,
    super.trackCount,
    super.followersCount,
    super.isFollowing,
    super.isVerified,
  });

  factory SearchArtistModel.fromJson(Map<String, dynamic> json) {
    return SearchArtistModel(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? '',
      username: json['username'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      bio: json['bio'] as String?,
      trackCount: (json['track_count'] as num?)?.toInt() ?? 0,
      followersCount: (json['followers_count'] as num?)?.toInt() ?? 0,
      isFollowing: json['is_following'] as bool?,
      isVerified: (json['is_verified'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'avatar_url': avatarUrl,
      'cover_image_url': coverImageUrl,
      'bio': bio,
      'track_count': trackCount,
      'followers_count': followersCount,
      'is_following': isFollowing,
      'is_verified': isVerified,
    };
  }
}
