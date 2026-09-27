import 'package:hums_mobile/features/search/domain/entities/search_track_entity.dart';

class SearchTrackModel extends SearchTrackEntity {
  const SearchTrackModel({
    required super.id,
    required super.ownerId,
    required super.title,
    super.description,
    super.artistName,
    super.albumName,
    super.genre,
    super.durationSeconds,
    super.waveformKey,
    required super.status,
    required super.createdAt,
    required super.updatedAt,
  });

  factory SearchTrackModel.fromJson(Map<String, dynamic> json) {
    return SearchTrackModel(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      artistName: json['artist_name'] as String?,
      albumName: json['album_name'] as String?,
      genre: json['genre'] as String?,
      durationSeconds: json['duration_seconds'] as int?,
      waveformKey: json['waveform_key'] as String?,
      status: json['status'] as String? ?? 'READY',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner_id': ownerId,
      'title': title,
      'description': description,
      'artist_name': artistName,
      'album_name': albumName,
      'genre': genre,
      'duration_seconds': durationSeconds,
      'waveform_key': waveformKey,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
