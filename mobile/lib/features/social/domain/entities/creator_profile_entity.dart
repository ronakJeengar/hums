import 'package:hums_mobile/features/audio/domain/entities/track_entity.dart';
import 'package:hums_mobile/features/playlists/domain/entities/playlist_entity.dart';
import 'package:hums_mobile/features/search/domain/entities/search_album_entity.dart';

class CreatorProfileEntity {
  final String id;
  final String name;
  final String? username;
  final String? bio;
  final String? avatarUrl;
  final String? coverImageUrl;
  final bool isVerified;
  final int followersCount;
  final bool? isFollowing;
  final int trackCount;
  final DateTime createdAt;

  const CreatorProfileEntity({
    required this.id,
    required this.name,
    this.username,
    this.bio,
    this.avatarUrl,
    this.coverImageUrl,
    this.isVerified = false,
    this.followersCount = 0,
    this.isFollowing,
    this.trackCount = 0,
    required this.createdAt,
  });

  CreatorProfileEntity copyWith({
    String? id,
    String? name,
    String? username,
    String? bio,
    String? avatarUrl,
    String? coverImageUrl,
    bool? isVerified,
    int? followersCount,
    bool? isFollowing,
    int? trackCount,
    DateTime? createdAt,
  }) {
    return CreatorProfileEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      isVerified: isVerified ?? this.isVerified,
      followersCount: followersCount ?? this.followersCount,
      isFollowing: isFollowing ?? this.isFollowing,
      trackCount: trackCount ?? this.trackCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class CreatorDetailEntity {
  final String id;
  final String name;
  final String? username;
  final String? bio;
  final String? avatarUrl;
  final String? coverImageUrl;
  final bool isVerified;
  final int followersCount;
  final bool? isFollowing;
  final List<TrackEntity> popularTracks;
  final List<TrackEntity> latestTracks;
  final List<SearchAlbumEntity> albums;
  final List<PlaylistEntity> publicPlaylists;
  final DateTime createdAt;

  const CreatorDetailEntity({
    required this.id,
    required this.name,
    this.username,
    this.bio,
    this.avatarUrl,
    this.coverImageUrl,
    this.isVerified = false,
    this.followersCount = 0,
    this.isFollowing,
    this.popularTracks = const [],
    this.latestTracks = const [],
    this.albums = const [],
    this.publicPlaylists = const [],
    required this.createdAt,
  });

  CreatorDetailEntity copyWith({
    String? id,
    String? name,
    String? username,
    String? bio,
    String? avatarUrl,
    String? coverImageUrl,
    bool? isVerified,
    int? followersCount,
    bool? isFollowing,
    List<TrackEntity>? popularTracks,
    List<TrackEntity>? latestTracks,
    List<SearchAlbumEntity>? albums,
    List<PlaylistEntity>? publicPlaylists,
    DateTime? createdAt,
  }) {
    return CreatorDetailEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      isVerified: isVerified ?? this.isVerified,
      followersCount: followersCount ?? this.followersCount,
      isFollowing: isFollowing ?? this.isFollowing,
      popularTracks: popularTracks ?? this.popularTracks,
      latestTracks: latestTracks ?? this.latestTracks,
      albums: albums ?? this.albums,
      publicPlaylists: publicPlaylists ?? this.publicPlaylists,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
