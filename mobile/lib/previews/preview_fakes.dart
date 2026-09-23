import 'package:hums_mobile/features/audio/domain/entities/track_entity.dart';
import 'package:hums_mobile/features/audio/domain/repositories/audio_repository.dart';
import 'package:hums_mobile/features/audio/presentation/providers/audio_upload_provider.dart';
import 'package:hums_mobile/features/audio/presentation/states/audio_upload_state.dart';
import 'package:hums_mobile/features/audio_player/domain/entities/playback_entity.dart';
import 'package:hums_mobile/features/audio_player/domain/entities/player_queue.dart';
import 'package:hums_mobile/features/audio_player/domain/repositories/audio_player_repository.dart';
import 'package:hums_mobile/features/audio_player/presentation/providers/audio_player_provider.dart';
import 'package:hums_mobile/features/audio_player/presentation/states/player_state.dart';
import 'package:hums_mobile/features/auth/domain/entities/auth_tokens_entity.dart';
import 'package:hums_mobile/features/auth/domain/entities/user_entity.dart';
import 'package:hums_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:hums_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:hums_mobile/features/auth/presentation/states/auth_state.dart';
import 'package:hums_mobile/features/playlists/domain/entities/playlist_entity.dart';
import 'package:hums_mobile/features/playlists/domain/repositories/playlist_repository.dart';
import 'package:hums_mobile/features/playlists/presentation/providers/playlist_provider.dart';
import 'package:hums_mobile/features/playlists/presentation/states/playlist_state.dart';
import 'package:hums_mobile/features/profile/domain/entities/profile_entity.dart';
import 'package:hums_mobile/features/profile/domain/repositories/profile_repository.dart';
import 'package:hums_mobile/features/profile/presentation/providers/profile_provider.dart';
import 'package:hums_mobile/features/profile/presentation/states/profile_state.dart';
import 'package:hums_mobile/previews/preview_data.dart';

// =============================================================================
// Fake Repositories
// =============================================================================

class FakeAuthRepository implements AuthRepository {
  @override
  Future<UserEntity> login({
    required String email,
    required String password,
  }) async => PreviewData.user;

  @override
  Future<UserEntity> register({
    required String name,
    required String email,
    required String password,
  }) async => PreviewData.user;

  @override
  Future<AuthTokensEntity> refreshToken() async => const AuthTokensEntity(
    accessToken: 'fake_access_token',
    refreshToken: 'fake_refresh_token',
    expiresIn: 3600,
  );

  @override
  Future<UserEntity?> getCurrentUser() async => PreviewData.user;

  @override
  Future<void> logout() async {}

  @override
  Future<void> requestPasswordReset(String email) async {}

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {}

  @override
  Future<bool> isAuthenticated() async => true;
}

class FakeProfileRepository implements ProfileRepository {
  @override
  Future<ProfileEntity> getProfile() async => PreviewData.profile;

  @override
  Future<ProfileEntity> updateProfile({
    String? name,
    String? email,
    String? bio,
  }) async => PreviewData.profile.copyWith(name: name, email: email, bio: bio);

  @override
  Future<ProfileEntity> uploadAvatar(String filePath) async =>
      PreviewData.profileWithAvatar;

  @override
  Future<ProfileEntity> removeAvatar() async =>
      PreviewData.profile.copyWith(clearAvatar: true);
}

class FakeAudioRepository implements AudioRepository {
  @override
  Future<List<TrackEntity>> listTracks({int skip = 0, int limit = 50}) async =>
      PreviewData.tracksList;

  @override
  Future<TrackEntity> getTrack(String trackId) async => PreviewData.trackReady1;

  @override
  Future<TrackStatusEntity> getTrackStatus(String trackId) async =>
      TrackStatusEntity(
        trackId: trackId,
        title: 'Midnight Resonance',
        status: 'READY',
        updatedAt: DateTime.now(),
      );

  @override
  Future<TrackEntity> uploadAudio({
    required String filePath,
    required String title,
    String? description,
    String? artistName,
    String? albumName,
    String? genre,
    void Function(double progress)? onProgress,
  }) async => PreviewData.trackUploaded;
}

class FakeAudioPlayerRepository implements AudioPlayerRepository {
  @override
  Future<TrackPlaybackEntity> getPlaybackSource(String trackId) async =>
      PreviewData.playbackReady;

  @override
  Future<void> loadTrack(TrackPlaybackEntity playback) async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> seekRelative(Duration offset) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}

  @override
  Stream<Duration> get positionStream => const Stream.empty();

  @override
  Stream<Duration?> get durationStream => const Stream.empty();

  @override
  Stream<Duration> get bufferedPositionStream => const Stream.empty();

  @override
  Stream<bool> get isPlayingStream => const Stream.empty();

  @override
  Stream<bool> get isBufferingStream => const Stream.empty();

  @override
  Stream<bool> get isCompletedStream => const Stream.empty();
}

class FakePlaylistRepository implements PlaylistRepository {
  @override
  Future<List<PlaylistEntity>> listPlaylists({
    int skip = 0,
    int limit = 50,
  }) async => PreviewData.playlistsList;

  @override
  Future<PlaylistDetailEntity> getPlaylistDetails(String playlistId) async =>
      PreviewData.playlistDetailPopulated;

  @override
  Future<PlaylistEntity> createPlaylist({
    required String name,
    String? description,
  }) async => PreviewData.playlist1;

  @override
  Future<PlaylistEntity> updatePlaylist(
    String playlistId, {
    String? name,
    String? description,
    bool? isPublic,
  }) async => PreviewData.playlist1;

  @override
  Future<void> deletePlaylist(String playlistId) async {}

  @override
  Future<PlaylistDetailEntity> addTrack(
    String playlistId,
    String trackId,
  ) async => PreviewData.playlistDetailPopulated;

  @override
  Future<PlaylistDetailEntity> removeTrack(
    String playlistId,
    String trackId,
  ) async => PreviewData.playlistDetailPopulated;

  @override
  Future<PlaylistDetailEntity> reorderTracks(
    String playlistId,
    List<String> trackIds,
  ) async => PreviewData.playlistDetailPopulated;

  @override
  Future<PlaylistEntity> uploadCover(
    String playlistId,
    String filePath,
  ) async => PreviewData.playlist1;

  @override
  Future<PlaylistEntity> removeCover(String playlistId) async =>
      PreviewData.playlist1;
}

// =============================================================================
// Preview Notifier Implementations
// =============================================================================

class PreviewAuthNotifier extends AuthNotifier {
  PreviewAuthNotifier([
    AuthState initialState = const AuthState.unauthenticated(),
  ]) : super(FakeAuthRepository()) {
    state = initialState;
  }

  @override
  Future<void> checkAuthStatus() async {}

  @override
  Future<bool> login({required String email, required String password}) async =>
      true;

  @override
  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async => true;

  @override
  Future<void> logout() async {
    state = const AuthState.unauthenticated();
  }

  @override
  Future<bool> requestPasswordReset(String email) async => true;

  @override
  Future<bool> resetPassword({
    required String token,
    required String newPassword,
  }) async => true;
}

class PreviewProfileNotifier extends ProfileNotifier {
  PreviewProfileNotifier([ProfileState? initialState])
    : super(FakeProfileRepository()) {
    state = initialState ?? ProfileState.loaded(PreviewData.profile);
  }

  @override
  Future<void> loadProfile() async {}

  @override
  Future<bool> updateProfile({
    String? name,
    String? email,
    String? bio,
  }) async => true;

  @override
  Future<bool> uploadAvatar(String filePath) async => true;

  @override
  Future<bool> removeAvatar() async => true;
}

class PreviewAudioPlayerNotifier extends AudioPlayerNotifier {
  PreviewAudioPlayerNotifier([PlayerState initialState = const PlayerState()])
    : super(FakeAudioPlayerRepository()) {
    state = initialState;
  }

  @override
  Future<void> playTrack(String trackId) async {}

  @override
  Future<void> playQueue(PlayerQueue queue, {int startIndex = 0}) async {}

  @override
  Future<void> togglePlayPause() async {
    if (state.isPlaying) {
      state = state.copyWith(status: PlayerStatus.paused);
    } else {
      state = state.copyWith(status: PlayerStatus.playing);
    }
  }

  @override
  Future<void> play() async {
    state = state.copyWith(status: PlayerStatus.playing);
  }

  @override
  Future<void> pause() async {
    state = state.copyWith(status: PlayerStatus.paused);
  }

  @override
  Future<void> resume() async {
    state = state.copyWith(status: PlayerStatus.playing);
  }

  @override
  Future<void> seek(Duration position) async {
    state = state.copyWith(position: position);
  }

  @override
  Future<void> seekRelative(Duration offset) async {
    final newPos = state.position + offset;
    state = state.copyWith(
      position: newPos < Duration.zero ? Duration.zero : newPos,
    );
  }

  @override
  Future<void> stop() async {
    state = state.copyWith(status: PlayerStatus.idle, position: Duration.zero);
  }

  @override
  Future<void> skipToNext() async {}

  @override
  Future<void> skipToPrevious() async {}
}

class PreviewAudioUploadNotifier extends AudioUploadNotifier {
  PreviewAudioUploadNotifier([AudioUploadState? initialState])
    : super(FakeAudioRepository()) {
    state = initialState ?? const AudioUploadState.initial();
  }

  @override
  void selectFile({
    required String path,
    required String name,
    required int size,
  }) {
    state = AudioUploadState.fileSelected(
      filePath: path,
      fileName: name,
      fileSizeBytes: size,
    );
  }

  @override
  void reset() {
    state = const AudioUploadState.initial();
  }

  @override
  Future<bool> uploadAudio({
    required String title,
    String? artistName,
    String? albumName,
    String? genre,
    String? description,
  }) async => true;
}

class PreviewPlaylistListNotifier extends PlaylistListNotifier {
  PreviewPlaylistListNotifier([PlaylistListState? initialState])
    : super(FakePlaylistRepository()) {
    state =
        initialState ??
        PlaylistListState(
          status: PlaylistListStatus.loaded,
          playlists: PreviewData.playlistsList,
        );
  }

  @override
  Future<void> loadPlaylists() async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<bool> deletePlaylist(String playlistId) async => true;
}

class PreviewPlaylistDetailNotifier extends PlaylistDetailNotifier {
  PreviewPlaylistDetailNotifier([PlaylistDetailState? initialState])
    : super(FakePlaylistRepository(), 'pl_preview_1') {
    state =
        initialState ??
        PlaylistDetailState(
          status: PlaylistDetailStatus.loaded,
          detail: PreviewData.playlistDetailPopulated,
        );
  }

  @override
  Future<void> loadDetails() async {}

  @override
  Future<bool> addTrack(String trackId) async => true;

  @override
  Future<bool> removeTrack(String trackId) async => true;

  @override
  Future<bool> reorderTracks(List<String> trackIds) async => true;
}

class PreviewPlaylistFormNotifier extends PlaylistFormNotifier {
  PreviewPlaylistFormNotifier([PlaylistFormState? initialState])
    : super(FakePlaylistRepository()) {
    state = initialState ?? const PlaylistFormState();
  }

  @override
  Future<PlaylistEntity?> createPlaylist({
    required String name,
    String? description,
    String? coverFilePath,
  }) async => PreviewData.playlist1;

  @override
  Future<PlaylistEntity?> updatePlaylist(
    String playlistId, {
    String? name,
    String? description,
    bool? isPublic,
    String? coverFilePath,
  }) async => PreviewData.playlist1;
}
