import 'package:hums_mobile/features/lyrics/domain/entities/lyric_line_entity.dart';

class LyricLineModel extends LyricLineEntity {
  const LyricLineModel({
    super.id,
    required super.sequence,
    required super.startMs,
    super.endMs,
    required super.text,
  });

  factory LyricLineModel.fromJson(Map<String, dynamic> json) {
    return LyricLineModel(
      id: json['id'] as String?,
      sequence: (json['sequence'] as num).toInt(),
      startMs: (json['start_ms'] as num).toInt(),
      endMs: (json['end_ms'] as num?)?.toInt(),
      text: json['text'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'sequence': sequence,
      'start_ms': startMs,
      if (endMs != null) 'end_ms': endMs,
      'text': text,
    };
  }

  factory LyricLineModel.fromEntity(LyricLineEntity entity) {
    return LyricLineModel(
      id: entity.id,
      sequence: entity.sequence,
      startMs: entity.startMs,
      endMs: entity.endMs,
      text: entity.text,
    );
  }
}
