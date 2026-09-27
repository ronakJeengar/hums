import 'package:hums_mobile/features/library/domain/entities/liked_track_entity.dart';

class LikedTrackModel extends LikedTrackEntity {
  const LikedTrackModel({
    required super.id,
    required super.title,
    super.artistName,
    super.albumName,
    super.genre,
    super.durationSeconds,
    super.waveformKey,
    required super.status,
    super.likesCount = 0,
    super.isLiked = true,
    required super.likedAt,
    required super.createdAt,
  });

  factory LikedTrackModel.fromJson(Map<String, dynamic> json) {
    return LikedTrackModel(
      id: json['id'] as String,
      title: json['title'] as String,
      artistName: json['artist_name'] as String?,
      albumName: json['album_name'] as String?,
      genre: json['genre'] as String?,
      durationSeconds: json['duration_seconds'] as int?,
      waveformKey: json['waveform_key'] as String?,
      status: json['status'] as String? ?? 'READY',
      likesCount: json['likes_count'] as int? ?? 0,
      isLiked: json['is_liked'] as bool? ?? true,
      likedAt: json['liked_at'] != null
          ? DateTime.parse(json['liked_at'] as String)
          : DateTime.now(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist_name': artistName,
      'album_name': albumName,
      'genre': genre,
      'duration_seconds': durationSeconds,
      'waveform_key': waveformKey,
      'status': status,
      'likes_count': likesCount,
      'is_liked': isLiked,
      'liked_at': likedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
