import 'package:hums_mobile/features/lyrics/data/models/lyric_line_model.dart';
import 'package:hums_mobile/features/lyrics/domain/entities/lyrics_entity.dart';

class LyricsModel extends LyricsEntity {
  const LyricsModel({
    super.id,
    required super.trackId,
    required super.status,
    super.language,
    super.source = LyricsSourceConstants.aiGenerated,
    super.isSynchronized = false,
    super.text,
    super.lines = const [],
    super.model,
    super.version = 'v1',
    super.errorMessage,
    super.updatedAt,
  });

  factory LyricsModel.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'] as List<dynamic>? ?? [];
    final parsedLines = rawLines
        .map((l) => LyricLineModel.fromJson(l as Map<String, dynamic>))
        .toList();

    return LyricsModel(
      id: json['id'] as String?,
      trackId: json['track_id'] as String,
      status: json['status'] as String? ?? LyricsStatusConstants.unavailable,
      language: json['language'] as String?,
      source: json['source'] as String? ?? LyricsSourceConstants.aiGenerated,
      isSynchronized: json['is_synchronized'] as bool? ?? false,
      text: json['text'] as String?,
      lines: parsedLines,
      model: json['model'] as String?,
      version: json['version'] as String? ?? 'v1',
      errorMessage: json['error_message'] as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'track_id': trackId,
      'status': status,
      if (language != null) 'language': language,
      'source': source,
      'is_synchronized': isSynchronized,
      if (text != null) 'text': text,
      'lines': lines
          .map((l) => (l is LyricLineModel ? l : LyricLineModel.fromEntity(l)).toJson())
          .toList(),
      if (model != null) 'model': model,
      'version': version,
      if (errorMessage != null) 'error_message': errorMessage,
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  factory LyricsModel.fromEntity(LyricsEntity entity) {
    return LyricsModel(
      id: entity.id,
      trackId: entity.trackId,
      status: entity.status,
      language: entity.language,
      source: entity.source,
      isSynchronized: entity.isSynchronized,
      text: entity.text,
      lines: entity.lines,
      model: entity.model,
      version: entity.version,
      errorMessage: entity.errorMessage,
      updatedAt: entity.updatedAt,
    );
  }
}
