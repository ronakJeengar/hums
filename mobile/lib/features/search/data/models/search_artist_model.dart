import 'package:hums_mobile/features/search/domain/entities/search_artist_entity.dart';

class SearchArtistModel extends SearchArtistEntity {
  const SearchArtistModel({
    required super.id,
    required super.name,
    super.username,
    super.avatarUrl,
    super.bio,
    super.trackCount,
  });

  factory SearchArtistModel.fromJson(Map<String, dynamic> json) {
    return SearchArtistModel(
      id: json['id'] as String,
      name: json['name'] as String,
      username: json['username'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      trackCount: (json['track_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'avatar_url': avatarUrl,
      'bio': bio,
      'track_count': trackCount,
    };
  }
}
