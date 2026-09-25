import 'package:hums_mobile/features/search/domain/entities/search_album_entity.dart';

class SearchAlbumModel extends SearchAlbumEntity {
  const SearchAlbumModel({
    required super.id,
    required super.title,
    super.artistName,
    super.trackCount,
    super.coverImageKey,
    super.coverImageUrl,
  });

  factory SearchAlbumModel.fromJson(Map<String, dynamic> json) {
    return SearchAlbumModel(
      id: json['id'] as String,
      title: json['title'] as String,
      artistName: json['artist_name'] as String?,
      trackCount: (json['track_count'] as num?)?.toInt() ?? 0,
      coverImageKey: json['cover_image_key'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist_name': artistName,
      'track_count': trackCount,
      'cover_image_key': coverImageKey,
      'cover_image_url': coverImageUrl,
    };
  }
}
