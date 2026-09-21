import 'package:hums_mobile/features/playlists/domain/entities/playlist_entity.dart';

enum PlaylistListStatus {
  initial,
  loading,
  loaded,
  error,
}

class PlaylistListState {
  final PlaylistListStatus status;
  final List<PlaylistEntity> playlists;
  final String? errorMessage;
  final bool isRefreshing;

  const PlaylistListState({
    this.status = PlaylistListStatus.initial,
    this.playlists = const [],
    this.errorMessage,
    this.isRefreshing = false,
  });

  PlaylistListState copyWith({
    PlaylistListStatus? status,
    List<PlaylistEntity>? playlists,
    String? errorMessage,
    bool? isRefreshing,
    bool clearError = false,
  }) {
    return PlaylistListState(
      status: status ?? this.status,
      playlists: playlists ?? this.playlists,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }

  bool get isInitial => status == PlaylistListStatus.initial;
  bool get isLoading => status == PlaylistListStatus.loading;
  bool get isLoaded => status == PlaylistListStatus.loaded;
  bool get hasError => status == PlaylistListStatus.error && errorMessage != null;
  bool get isEmpty => isLoaded && playlists.isEmpty;
}

enum PlaylistDetailStatus {
  initial,
  loading,
  loaded,
  error,
}

class PlaylistDetailState {
  final PlaylistDetailStatus status;
  final PlaylistDetailEntity? detail;
  final String? errorMessage;
  final bool isMutating;
  final bool isUploadingCover;

  const PlaylistDetailState({
    this.status = PlaylistDetailStatus.initial,
    this.detail,
    this.errorMessage,
    this.isMutating = false,
    this.isUploadingCover = false,
  });

  PlaylistDetailState copyWith({
    PlaylistDetailStatus? status,
    PlaylistDetailEntity? detail,
    String? errorMessage,
    bool? isMutating,
    bool? isUploadingCover,
    bool clearError = false,
  }) {
    return PlaylistDetailState(
      status: status ?? this.status,
      detail: detail ?? this.detail,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isMutating: isMutating ?? this.isMutating,
      isUploadingCover: isUploadingCover ?? this.isUploadingCover,
    );
  }

  bool get isInitial => status == PlaylistDetailStatus.initial;
  bool get isLoading => status == PlaylistDetailStatus.loading;
  bool get isLoaded => status == PlaylistDetailStatus.loaded;
  bool get hasError => status == PlaylistDetailStatus.error && errorMessage != null;
  bool get isBusy => isLoading || isMutating || isUploadingCover;
}

enum PlaylistFormStatus {
  initial,
  submitting,
  success,
  error,
}

class PlaylistFormState {
  final PlaylistFormStatus status;
  final PlaylistEntity? playlist;
  final String? errorMessage;

  const PlaylistFormState({
    this.status = PlaylistFormStatus.initial,
    this.playlist,
    this.errorMessage,
  });

  PlaylistFormState copyWith({
    PlaylistFormStatus? status,
    PlaylistEntity? playlist,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PlaylistFormState(
      status: status ?? this.status,
      playlist: playlist ?? this.playlist,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  bool get isSubmitting => status == PlaylistFormStatus.submitting;
  bool get isSuccess => status == PlaylistFormStatus.success;
  bool get hasError => status == PlaylistFormStatus.error && errorMessage != null;
}
