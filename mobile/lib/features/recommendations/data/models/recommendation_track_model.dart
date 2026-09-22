import 'package:hums_mobile/features/recommendations/domain/entities/recommendation_track_entity.dart';

class RecommendationTrackModel {
  final String id;
  final String title;
  final String? artistName;
  final String? albumName;
  final String? genre;
  final int? durationSeconds;
  final String? artworkUrl;
  final String status;
  final String? waveformKey;

  const RecommendationTrackModel({
    required this.id,
    required this.title,
    this.artistName,
    this.albumName,
    this.genre,
    this.durationSeconds,
    this.artworkUrl,
    required this.status,
    this.waveformKey,
  });

  factory RecommendationTrackModel.fromJson(Map<String, dynamic> json) {
    return RecommendationTrackModel(
      id: json['id'] as String,
      title: (json['title'] as String?) ?? '',
      artistName: json['artist_name'] as String?,
      albumName: json['album_name'] as String?,
      genre: json['genre'] as String?,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
      artworkUrl: json['artwork_url'] as String?,
      status: (json['status'] as String?) ?? 'READY',
      waveformKey: json['waveform_key'] as String?,
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
      'artwork_url': artworkUrl,
      'status': status,
      'waveform_key': waveformKey,
    };
  }

  RecommendationTrackEntity toEntity() {
    return RecommendationTrackEntity(
      id: id,
      title: title,
      artistName: artistName,
      albumName: albumName,
      genre: genre,
      durationSeconds: durationSeconds,
      artworkUrl: artworkUrl,
      status: status,
      waveformKey: waveformKey,
    );
  }
}
