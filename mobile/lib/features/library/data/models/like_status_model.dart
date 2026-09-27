import 'package:hums_mobile/features/library/domain/entities/like_status_entity.dart';

class LikeStatusModel extends LikeStatusEntity {
  const LikeStatusModel({
    required super.trackId,
    required super.isLiked,
    required super.likesCount,
  });

  factory LikeStatusModel.fromJson(Map<String, dynamic> json) {
    return LikeStatusModel(
      trackId: json['track_id'] as String,
      isLiked: json['is_liked'] as bool? ?? false,
      likesCount: json['likes_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'track_id': trackId,
      'is_liked': isLiked,
      'likes_count': likesCount,
    };
  }
}
