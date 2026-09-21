import 'package:hums_mobile/features/playlists/domain/entities/playlist_entity.dart';

class PlaylistModel {
  final String id;
  final String ownerId;
  final String name;
  final String? description;
  final String? coverImageKey;
  final String? coverImageUrl;
  final bool isPublic;
  final int trackCount;
  final int durationSeconds;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PlaylistModel({
    required this.id,
    required this.ownerId,
    required this.name,
    this.description,
    this.coverImageKey,
    this.coverImageUrl,
    this.isPublic = false,
    this.trackCount = 0,
    this.durationSeconds = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PlaylistModel.fromJson(Map<String, dynamic> json) {
    return PlaylistModel(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      name: (json['name'] as String?) ?? '',
      description: json['description'] as String?,
      coverImageKey: json['cover_image_key'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      isPublic: (json['is_public'] as bool?) ?? false,
      trackCount: (json['track_count'] as num?)?.toInt() ?? 0,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  PlaylistEntity toEntity() {
    return PlaylistEntity(
      id: id,
      ownerId: ownerId,
      name: name,
      description: description,
      coverImageKey: coverImageKey,
      coverImageUrl: coverImageUrl,
      isPublic: isPublic,
      trackCount: trackCount,
      durationSeconds: durationSeconds,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class PlaylistTrackModel {
  final String id;
  final String trackId;
  final int position;
  final DateTime addedAt;
  final String title;
  final String? artistName;
  final String? albumName;
  final int? durationSeconds;
  final String? waveformKey;
  final String status;

  const PlaylistTrackModel({
    required this.id,
    required this.trackId,
    required this.position,
    required this.addedAt,
    required this.title,
    this.artistName,
    this.albumName,
    this.durationSeconds,
    this.waveformKey,
    required this.status,
  });

  factory PlaylistTrackModel.fromJson(Map<String, dynamic> json) {
    return PlaylistTrackModel(
      id: json['id'] as String,
      trackId: json['track_id'] as String,
      position: (json['position'] as num?)?.toInt() ?? 0,
      addedAt: json['added_at'] != null
          ? DateTime.parse(json['added_at'] as String)
          : DateTime.now(),
      title: (json['title'] as String?) ?? '',
      artistName: json['artist_name'] as String?,
      albumName: json['album_name'] as String?,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
      waveformKey: json['waveform_key'] as String?,
      status: (json['status'] as String?) ?? 'READY',
    );
  }

  PlaylistTrackEntity toEntity() {
    return PlaylistTrackEntity(
      id: id,
      trackId: trackId,
      position: position,
      addedAt: addedAt,
      title: title,
      artistName: artistName,
      albumName: albumName,
      durationSeconds: durationSeconds,
      waveformKey: waveformKey,
      status: status,
    );
  }
}

class PlaylistDetailModel {
  final PlaylistModel playlist;
  final List<PlaylistTrackModel> tracks;

  const PlaylistDetailModel({
    required this.playlist,
    required this.tracks,
  });

  factory PlaylistDetailModel.fromJson(Map<String, dynamic> json) {
    final playlist = PlaylistModel.fromJson(json);
    final rawTracks = json['tracks'] as List<dynamic>? ?? [];
    final tracks = rawTracks
        .map((t) => PlaylistTrackModel.fromJson(t as Map<String, dynamic>))
        .toList();

    return PlaylistDetailModel(
      playlist: playlist,
      tracks: tracks,
    );
  }

  PlaylistDetailEntity toEntity() {
    return PlaylistDetailEntity(
      playlist: playlist.toEntity(),
      tracks: tracks.map((t) => t.toEntity()).toList(),
    );
  }
}
