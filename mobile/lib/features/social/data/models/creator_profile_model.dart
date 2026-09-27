import 'package:hums_mobile/features/audio/data/models/track_model.dart';
import 'package:hums_mobile/features/playlists/data/models/playlist_model.dart';
import 'package:hums_mobile/features/search/data/models/search_album_model.dart';
import 'package:hums_mobile/features/social/domain/entities/creator_profile_entity.dart';

class CreatorProfileModel extends CreatorProfileEntity {
  const CreatorProfileModel({
    required super.id,
    required super.name,
    super.username,
    super.bio,
    super.avatarUrl,
    super.coverImageUrl,
    super.isVerified,
    super.followersCount,
    super.isFollowing,
    super.trackCount,
    required super.createdAt,
  });

  factory CreatorProfileModel.fromJson(Map<String, dynamic> json) {
    return CreatorProfileModel(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? '',
      username: json['username'] as String?,
      bio: json['bio'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      isVerified: (json['is_verified'] as bool?) ?? false,
      followersCount: (json['followers_count'] as num?)?.toInt() ?? 0,
      isFollowing: json['is_following'] as bool?,
      trackCount: (json['track_count'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'bio': bio,
      'avatar_url': avatarUrl,
      'cover_image_url': coverImageUrl,
      'is_verified': isVerified,
      'followers_count': followersCount,
      'is_following': isFollowing,
      'track_count': trackCount,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class CreatorDetailModel extends CreatorDetailEntity {
  const CreatorDetailModel({
    required super.id,
    required super.name,
    super.username,
    super.bio,
    super.avatarUrl,
    super.coverImageUrl,
    super.isVerified,
    super.followersCount,
    super.isFollowing,
    super.popularTracks,
    super.latestTracks,
    super.albums,
    super.publicPlaylists,
    required super.createdAt,
  });

  factory CreatorDetailModel.fromJson(Map<String, dynamic> json) {
    final rawPopular = json['popular_tracks'] as List<dynamic>? ?? [];
    final rawLatest = json['latest_tracks'] as List<dynamic>? ?? [];
    final rawAlbums = json['albums'] as List<dynamic>? ?? [];
    final rawPlaylists = json['public_playlists'] as List<dynamic>? ?? [];

    return CreatorDetailModel(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? '',
      username: json['username'] as String?,
      bio: json['bio'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      isVerified: (json['is_verified'] as bool?) ?? false,
      followersCount: (json['followers_count'] as num?)?.toInt() ?? 0,
      isFollowing: json['is_following'] as bool?,
      popularTracks: rawPopular
          .map((t) => TrackModel.fromJson(t as Map<String, dynamic>).toEntity())
          .toList(),
      latestTracks: rawLatest
          .map((t) => TrackModel.fromJson(t as Map<String, dynamic>).toEntity())
          .toList(),
      albums: rawAlbums
          .map((a) => SearchAlbumModel.fromJson(a as Map<String, dynamic>))
          .toList(),
      publicPlaylists: rawPlaylists
          .map((p) => PlaylistModel.fromJson(p as Map<String, dynamic>).toEntity())
          .toList(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}
