class LikeStatusEntity {
  final String trackId;
  final bool isLiked;
  final int likesCount;

  const LikeStatusEntity({
    required this.trackId,
    required this.isLiked,
    required this.likesCount,
  });
}
