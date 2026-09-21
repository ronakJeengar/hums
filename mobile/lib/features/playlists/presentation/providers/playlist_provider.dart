import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hums_mobile/core/network/api_client.dart';
import 'package:hums_mobile/core/network/api_exception.dart';
import 'package:hums_mobile/features/playlists/data/datasources/playlist_remote_data_source.dart';
import 'package:hums_mobile/features/playlists/data/repositories/playlist_repository_impl.dart';
import 'package:hums_mobile/features/playlists/domain/entities/playlist_entity.dart';
import 'package:hums_mobile/features/playlists/domain/repositories/playlist_repository.dart';
import 'package:hums_mobile/features/playlists/presentation/states/playlist_state.dart';

final playlistRemoteDataSourceProvider = Provider<PlaylistRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return PlaylistRemoteDataSourceImpl(apiClient);
});

final playlistRepositoryProvider = Provider<PlaylistRepository>((ref) {
  final remoteDataSource = ref.watch(playlistRemoteDataSourceProvider);
  return PlaylistRepositoryImpl(remoteDataSource);
});

// Playlists List Provider
final playlistListNotifierProvider =
    StateNotifierProvider<PlaylistListNotifier, PlaylistListState>((ref) {
  final repository = ref.watch(playlistRepositoryProvider);
  return PlaylistListNotifier(repository);
});

class PlaylistListNotifier extends StateNotifier<PlaylistListState> {
  final PlaylistRepository _repository;

  PlaylistListNotifier(this._repository) : super(const PlaylistListState());

  Future<void> loadPlaylists() async {
    state = state.copyWith(status: PlaylistListStatus.loading, clearError: true);
    try {
      final playlists = await _repository.listPlaylists();
      state = state.copyWith(
        status: PlaylistListStatus.loaded,
        playlists: playlists,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        status: PlaylistListStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        status: PlaylistListStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(isRefreshing: true, clearError: true);
    try {
      final playlists = await _repository.listPlaylists();
      state = state.copyWith(
        status: PlaylistListStatus.loaded,
        playlists: playlists,
        isRefreshing: false,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        isRefreshing: false,
        errorMessage: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        isRefreshing: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<bool> deletePlaylist(String playlistId) async {
    try {
      await _repository.deletePlaylist(playlistId);
      final updatedList =
          state.playlists.where((p) => p.id != playlistId).toList();
      state = state.copyWith(playlists: updatedList);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  void addOrUpdatePlaylist(PlaylistEntity playlist) {
    final index = state.playlists.indexWhere((p) => p.id == playlist.id);
    if (index >= 0) {
      final updated = List<PlaylistEntity>.from(state.playlists);
      updated[index] = playlist;
      state = state.copyWith(playlists: updated);
    } else {
      state = state.copyWith(playlists: [playlist, ...state.playlists]);
    }
  }
}

// Playlist Detail Provider (family by playlistId)
final playlistDetailNotifierProvider = StateNotifierProvider.family<
    PlaylistDetailNotifier, PlaylistDetailState, String>((ref, playlistId) {
  final repository = ref.watch(playlistRepositoryProvider);
  return PlaylistDetailNotifier(repository, playlistId);
});

class PlaylistDetailNotifier extends StateNotifier<PlaylistDetailState> {
  final PlaylistRepository _repository;
  final String playlistId;

  PlaylistDetailNotifier(this._repository, this.playlistId)
      : super(const PlaylistDetailState());

  Future<void> loadDetails() async {
    state = state.copyWith(status: PlaylistDetailStatus.loading, clearError: true);
    try {
      final detail = await _repository.getPlaylistDetails(playlistId);
      state = state.copyWith(
        status: PlaylistDetailStatus.loaded,
        detail: detail,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        status: PlaylistDetailStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        status: PlaylistDetailStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<bool> addTrack(String trackId) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      final updatedDetail = await _repository.addTrack(playlistId, trackId);
      state = state.copyWith(
        detail: updatedDetail,
        isMutating: false,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isMutating: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isMutating: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> removeTrack(String trackId) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      final updatedDetail = await _repository.removeTrack(playlistId, trackId);
      state = state.copyWith(
        detail: updatedDetail,
        isMutating: false,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isMutating: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isMutating: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> reorderTracks(List<String> trackIds) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      final updatedDetail = await _repository.reorderTracks(playlistId, trackIds);
      state = state.copyWith(
        detail: updatedDetail,
        isMutating: false,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isMutating: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isMutating: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> uploadCover(String filePath) async {
    state = state.copyWith(isUploadingCover: true, clearError: true);
    try {
      final updatedPlaylist = await _repository.uploadCover(playlistId, filePath);
      if (state.detail != null) {
        state = state.copyWith(
          detail: PlaylistDetailEntity(
            playlist: updatedPlaylist,
            tracks: state.detail!.tracks,
          ),
          isUploadingCover: false,
        );
      } else {
        state = state.copyWith(isUploadingCover: false);
      }
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isUploadingCover: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isUploadingCover: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> removeCover() async {
    state = state.copyWith(isUploadingCover: true, clearError: true);
    try {
      final updatedPlaylist = await _repository.removeCover(playlistId);
      if (state.detail != null) {
        state = state.copyWith(
          detail: PlaylistDetailEntity(
            playlist: updatedPlaylist,
            tracks: state.detail!.tracks,
          ),
          isUploadingCover: false,
        );
      } else {
        state = state.copyWith(isUploadingCover: false);
      }
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isUploadingCover: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isUploadingCover: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> updateMetadata({
    String? name,
    String? description,
    bool? isPublic,
  }) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      final updatedPlaylist = await _repository.updatePlaylist(
        playlistId,
        name: name,
        description: description,
        isPublic: isPublic,
      );
      if (state.detail != null) {
        state = state.copyWith(
          detail: PlaylistDetailEntity(
            playlist: updatedPlaylist,
            tracks: state.detail!.tracks,
          ),
          isMutating: false,
        );
      } else {
        state = state.copyWith(isMutating: false);
      }
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isMutating: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isMutating: false, errorMessage: e.toString());
      return false;
    }
  }
}

// Playlist Form Provider
final playlistFormNotifierProvider =
    StateNotifierProvider<PlaylistFormNotifier, PlaylistFormState>((ref) {
  final repository = ref.watch(playlistRepositoryProvider);
  return PlaylistFormNotifier(repository);
});

class PlaylistFormNotifier extends StateNotifier<PlaylistFormState> {
  final PlaylistRepository _repository;

  PlaylistFormNotifier(this._repository) : super(const PlaylistFormState());

  void reset() {
    state = const PlaylistFormState();
  }

  Future<PlaylistEntity?> createPlaylist({
    required String name,
    String? description,
    String? coverFilePath,
  }) async {
    state = state.copyWith(
      status: PlaylistFormStatus.submitting,
      clearError: true,
    );
    try {
      var playlist = await _repository.createPlaylist(
        name: name,
        description: description,
      );

      if (coverFilePath != null && coverFilePath.isNotEmpty) {
        playlist = await _repository.uploadCover(playlist.id, coverFilePath);
      }

      state = state.copyWith(
        status: PlaylistFormStatus.success,
        playlist: playlist,
      );
      return playlist;
    } on ApiException catch (e) {
      state = state.copyWith(
        status: PlaylistFormStatus.error,
        errorMessage: e.message,
      );
      return null;
    } catch (e) {
      state = state.copyWith(
        status: PlaylistFormStatus.error,
        errorMessage: e.toString(),
      );
      return null;
    }
  }

  Future<PlaylistEntity?> updatePlaylist(
    String playlistId, {
    String? name,
    String? description,
    bool? isPublic,
    String? coverFilePath,
  }) async {
    state = state.copyWith(
      status: PlaylistFormStatus.submitting,
      clearError: true,
    );
    try {
      var playlist = await _repository.updatePlaylist(
        playlistId,
        name: name,
        description: description,
        isPublic: isPublic,
      );

      if (coverFilePath != null && coverFilePath.isNotEmpty) {
        playlist = await _repository.uploadCover(playlistId, coverFilePath);
      }

      state = state.copyWith(
        status: PlaylistFormStatus.success,
        playlist: playlist,
      );
      return playlist;
    } on ApiException catch (e) {
      state = state.copyWith(
        status: PlaylistFormStatus.error,
        errorMessage: e.message,
      );
      return null;
    } catch (e) {
      state = state.copyWith(
        status: PlaylistFormStatus.error,
        errorMessage: e.toString(),
      );
      return null;
    }
  }
}
