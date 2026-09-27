class FollowState {
  final bool isFollowing;
  final int followersCount;
  final bool isLoading;
  final String? errorMessage;

  const FollowState({
    this.isFollowing = false,
    this.followersCount = 0,
    this.isLoading = false,
    this.errorMessage,
  });

  FollowState copyWith({
    bool? isFollowing,
    int? followersCount,
    bool? isLoading,
    String? errorMessage,
  }) {
    return FollowState(
      isFollowing: isFollowing ?? this.isFollowing,
      followersCount: followersCount ?? this.followersCount,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}
