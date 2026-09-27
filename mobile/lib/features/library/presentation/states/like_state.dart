class LikeState {
  final bool isLiked;
  final int likesCount;
  final bool isLoading;
  final String? errorMessage;

  const LikeState({
    this.isLiked = false,
    this.likesCount = 0,
    this.isLoading = false,
    this.errorMessage,
  });

  LikeState copyWith({
    bool? isLiked,
    int? likesCount,
    bool? isLoading,
    String? errorMessage,
  }) {
    return LikeState(
      isLiked: isLiked ?? this.isLiked,
      likesCount: likesCount ?? this.likesCount,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}
