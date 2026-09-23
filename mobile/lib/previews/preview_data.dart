import 'package:hums_mobile/features/audio/domain/entities/track_entity.dart';
import 'package:hums_mobile/features/audio_player/domain/entities/playback_entity.dart';
import 'package:hums_mobile/features/audio_player/domain/entities/player_error.dart';
import 'package:hums_mobile/features/audio_player/presentation/states/player_state.dart';
import 'package:hums_mobile/features/auth/domain/entities/user_entity.dart';
import 'package:hums_mobile/features/playlists/domain/entities/playlist_entity.dart';
import 'package:hums_mobile/features/profile/domain/entities/profile_entity.dart';

/// Centralized preview fixture data for widget previews.
///
/// Contains realistic, deterministic test entities adhering to existing
/// domain models. No network or backend calls are needed.
abstract class PreviewData {
  static final DateTime _baseDate = DateTime(2026, 9, 21, 12, 0, 0);

  // ---------------------------------------------------------------------------
  // User Fixtures
  // ---------------------------------------------------------------------------

  static final UserEntity user = UserEntity(
    id: 'usr_preview_1',
    name: 'Elena Rostova',
    email: 'elena.rostova@example.com',
    username: 'elena_sound',
    fullName: 'Elena Rostova',
    avatarUrl: null,
    isActive: true,
    isVerified: true,
    lastLoginAt: _baseDate,
  );

  static final UserEntity userWithAvatar = UserEntity(
    id: 'usr_preview_2',
    name: 'Marcus Chen',
    email: 'marcus.chen@example.com',
    username: 'marcus_audio',
    fullName: 'Marcus Chen',
    avatarUrl:
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400',
    isActive: true,
    isVerified: true,
    lastLoginAt: _baseDate,
  );

  // ---------------------------------------------------------------------------
  // Profile Fixtures
  // ---------------------------------------------------------------------------

  static final ProfileEntity profile = ProfileEntity(
    id: 'usr_preview_1',
    name: 'Elena Rostova',
    email: 'elena.rostova@example.com',
    username: 'elena_sound',
    avatarUrl: null,
    bio:
        'Independent sound artist & composer. Exploring analog synthesizers, acoustic resonance, and minimalist field recordings.',
    createdAt: _baseDate.subtract(const Duration(days: 90)),
    updatedAt: _baseDate,
  );

  static final ProfileEntity profileWithAvatar = ProfileEntity(
    id: 'usr_preview_2',
    name: 'Marcus Chen',
    email: 'marcus.chen@example.com',
    username: 'marcus_audio',
    avatarUrl:
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400',
    bio:
        'Lo-fi beats producer from Seattle. Making warm tape loops for late-night study sessions.',
    createdAt: _baseDate.subtract(const Duration(days: 120)),
    updatedAt: _baseDate,
  );

  // ---------------------------------------------------------------------------
  // Track Fixtures
  // ---------------------------------------------------------------------------

  static final TrackEntity trackReady1 = TrackEntity(
    id: 'trk_preview_1',
    ownerId: 'usr_preview_1',
    title: 'Midnight Resonance',
    artistName: 'Elena Rostova',
    albumName: 'Acoustic Horizons',
    genre: 'Ambient',
    durationSeconds: 214,
    status: 'READY',
    waveformKey: 'waveforms/trk_preview_1.json',
    createdAt: _baseDate.subtract(const Duration(days: 3)),
    updatedAt: _baseDate.subtract(const Duration(days: 3)),
  );

  static final TrackEntity trackReady2 = TrackEntity(
    id: 'trk_preview_2',
    ownerId: 'usr_preview_1',
    title: 'Cedar Smoke',
    artistName: 'Elena Rostova',
    albumName: 'Acoustic Horizons',
    genre: 'Folk / Acoustic',
    durationSeconds: 185,
    status: 'READY',
    waveformKey: 'waveforms/trk_preview_2.json',
    createdAt: _baseDate.subtract(const Duration(days: 5)),
    updatedAt: _baseDate.subtract(const Duration(days: 5)),
  );

  static final TrackEntity trackProcessing = TrackEntity(
    id: 'trk_preview_3',
    ownerId: 'usr_preview_1',
    title: 'Rain on Copper Roof',
    artistName: 'Elena Rostova',
    albumName: 'Field Notes',
    genre: 'Field Recording',
    durationSeconds: 310,
    status: 'PROCESSING',
    createdAt: _baseDate.subtract(const Duration(minutes: 15)),
    updatedAt: _baseDate.subtract(const Duration(minutes: 2)),
  );

  static final TrackEntity trackUploaded = TrackEntity(
    id: 'trk_preview_4',
    ownerId: 'usr_preview_1',
    title: 'Tape Echo Improvisation',
    artistName: 'Elena Rostova',
    albumName: 'Demos',
    genre: 'Experimental',
    durationSeconds: null,
    status: 'UPLOADED',
    createdAt: _baseDate.subtract(const Duration(minutes: 5)),
    updatedAt: _baseDate.subtract(const Duration(minutes: 5)),
  );

  static final TrackEntity trackFailed = TrackEntity(
    id: 'trk_preview_5',
    ownerId: 'usr_preview_1',
    title: 'Corrupted Session Take 1',
    artistName: 'Elena Rostova',
    genre: 'Unknown',
    durationSeconds: null,
    status: 'FAILED',
    createdAt: _baseDate.subtract(const Duration(hours: 2)),
    updatedAt: _baseDate.subtract(const Duration(hours: 1)),
  );

  static final List<TrackEntity> tracksList = [
    trackReady1,
    trackReady2,
    trackProcessing,
    trackUploaded,
    trackFailed,
  ];

  // ---------------------------------------------------------------------------
  // Playback Fixtures (for Audio Player)
  // ---------------------------------------------------------------------------

  static final TrackPlaybackEntity playbackReady = TrackPlaybackEntity(
    trackId: 'trk_preview_1',
    title: 'Midnight Resonance',
    artistName: 'Elena Rostova',
    albumName: 'Acoustic Horizons',
    genre: 'Ambient',
    durationSeconds: 214,
    status: 'READY',
    audio: const AudioSourceEntity(
      url: 'https://cdn.hums.audio/preview/stream.mp3',
      format: 'm4a',
      codec: 'aac',
      bitrateKbps: 192,
      durationSeconds: 214,
      fileSizeBytes: 5200000,
    ),
    waveformSamples: List<double>.generate(
      100,
      (i) => (0.15 + 0.7 * ((i % 12) / 12.0) * ((100 - i) / 100.0)).clamp(
        0.05,
        1.0,
      ),
    ),
  );

  // ---------------------------------------------------------------------------
  // Player State Fixtures
  // ---------------------------------------------------------------------------

  static const PlayerState playerIdle = PlayerState(status: PlayerStatus.idle);

  static final PlayerState playerPlaying = PlayerState(
    status: PlayerStatus.playing,
    track: playbackReady,
    position: const Duration(seconds: 45),
    duration: const Duration(seconds: 214),
    bufferedPosition: const Duration(seconds: 120),
  );

  static final PlayerState playerPaused = PlayerState(
    status: PlayerStatus.paused,
    track: playbackReady,
    position: const Duration(seconds: 45),
    duration: const Duration(seconds: 214),
    bufferedPosition: const Duration(seconds: 120),
  );

  static final PlayerState playerBuffering = PlayerState(
    status: PlayerStatus.buffering,
    track: playbackReady,
    position: const Duration(seconds: 45),
    duration: const Duration(seconds: 214),
    bufferedPosition: const Duration(seconds: 50),
  );

  static final PlayerState playerError = PlayerState(
    status: PlayerStatus.error,
    track: playbackReady,
    error: const PlayerError(
      type: PlayerErrorType.networkError,
      message: 'Network connection lost while streaming audio.',
    ),
  );

  // ---------------------------------------------------------------------------
  // Playlist Fixtures
  // ---------------------------------------------------------------------------

  static final PlaylistEntity playlist1 = PlaylistEntity(
    id: 'pl_preview_1',
    ownerId: 'usr_preview_1',
    name: 'Late Night Focus',
    description:
        'Deep acoustic resonance and minimalist ambient tracks for sustained attention.',
    coverImageUrl: null,
    isPublic: true,
    trackCount: 4,
    durationSeconds: 709,
    createdAt: _baseDate.subtract(const Duration(days: 10)),
    updatedAt: _baseDate.subtract(const Duration(days: 1)),
  );

  static final PlaylistEntity playlist2 = PlaylistEntity(
    id: 'pl_preview_2',
    ownerId: 'usr_preview_1',
    name: 'Analog Warmth',
    description: 'Vintage synthesizers and acoustic tape recordings.',
    coverImageUrl: null,
    isPublic: false,
    trackCount: 2,
    durationSeconds: 399,
    createdAt: _baseDate.subtract(const Duration(days: 20)),
    updatedAt: _baseDate.subtract(const Duration(days: 4)),
  );

  static final List<PlaylistEntity> playlistsList = [playlist1, playlist2];

  static final PlaylistTrackEntity playlistTrack1 = PlaylistTrackEntity(
    id: 'plt_1',
    trackId: 'trk_preview_1',
    position: 0,
    addedAt: _baseDate.subtract(const Duration(days: 5)),
    title: 'Midnight Resonance',
    artistName: 'Elena Rostova',
    albumName: 'Acoustic Horizons',
    durationSeconds: 214,
    status: 'READY',
  );

  static final PlaylistTrackEntity playlistTrack2 = PlaylistTrackEntity(
    id: 'plt_2',
    trackId: 'trk_preview_2',
    position: 1,
    addedAt: _baseDate.subtract(const Duration(days: 4)),
    title: 'Cedar Smoke',
    artistName: 'Elena Rostova',
    albumName: 'Acoustic Horizons',
    durationSeconds: 185,
    status: 'READY',
  );

  static final PlaylistDetailEntity playlistDetailPopulated =
      PlaylistDetailEntity(
        playlist: playlist1,
        tracks: [playlistTrack1, playlistTrack2],
      );

  static final PlaylistDetailEntity playlistDetailEmpty = PlaylistDetailEntity(
    playlist: PlaylistEntity(
      id: 'pl_empty_1',
      ownerId: 'usr_preview_1',
      name: 'New Empty Playlist',
      description: 'A freshly created playlist awaiting your favorite sounds.',
      isPublic: false,
      trackCount: 0,
      durationSeconds: 0,
      createdAt: _baseDate,
      updatedAt: _baseDate,
    ),
    tracks: const [],
  );

  // ---------------------------------------------------------------------------
  // System Health Fixtures
  // ---------------------------------------------------------------------------

  static const Map<String, dynamic> systemHealth = {
    'status': 'healthy',
    'version': '1.0.0',
    'environment': 'preview',
    'services': {
      'database': 'connected',
      'redis': 'connected',
      'storage': 'connected',
      'celery': 'active',
    },
  };
}
