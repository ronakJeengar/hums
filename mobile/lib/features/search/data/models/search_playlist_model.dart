import 'package:hums_mobile/features/search/domain/entities/search_playlist_entity.dart';

class SearchPlaylistModel extends SearchPlaylistEntity {
  const SearchPlaylistModel({
    required super.id,
    required super.ownerId,
    required super.name,
    super.description,
    super.coverImageKey,
    super.coverImageUrl,
    super.isPublic,
    super.trackCount,
    required super.createdAt,
    required super.updatedAt,
  });

  factory SearchPlaylistModel.fromJson(Map<String, dynamic> json) {
    return SearchPlaylistModel(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      coverImageKey: json['cover_image_key'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      isPublic: json['is_public'] as bool? ?? false,
      trackCount: (json['track_count'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner_id': ownerId,
      'name': name,
      'description': description,
      'cover_image_key': coverImageKey,
      'cover_image_url': coverImageUrl,
      'is_public': isPublic,
      'track_count': trackCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
