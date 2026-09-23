import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hums_mobile/core/theme/app_theme.dart';
import 'package:hums_mobile/features/audio/presentation/providers/audio_upload_provider.dart';
import 'package:hums_mobile/features/audio_player/presentation/providers/audio_player_provider.dart';
import 'package:hums_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:hums_mobile/features/auth/presentation/states/auth_state.dart';
import 'package:hums_mobile/features/common/presentation/screens/home_screen.dart';
import 'package:hums_mobile/features/playlists/presentation/providers/playlist_provider.dart';
import 'package:hums_mobile/features/profile/presentation/providers/profile_provider.dart';
import 'package:hums_mobile/features/profile/presentation/states/profile_state.dart';
import 'package:hums_mobile/previews/preview_data.dart';
import 'package:hums_mobile/previews/preview_fakes.dart';

/// Default Riverpod overrides for all preview environments.
///
/// Ensures every screen renders with deterministic, zero-network mock data
/// without requiring a live backend, real database, or audio engine.
final List<Override> defaultPreviewOverrides = [
  authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
  authNotifierProvider.overrideWith(
    (ref) => PreviewAuthNotifier(AuthState.authenticated(PreviewData.user)),
  ),
  profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
  profileNotifierProvider.overrideWith(
    (ref) => PreviewProfileNotifier(ProfileState.loaded(PreviewData.profile)),
  ),
  audioPlayerRepositoryProvider.overrideWithValue(FakeAudioPlayerRepository()),
  audioPlayerNotifierProvider.overrideWith(
    (ref) => PreviewAudioPlayerNotifier(),
  ),
  audioRepositoryProvider.overrideWithValue(FakeAudioRepository()),
  audioUploadNotifierProvider.overrideWith(
    (ref) => PreviewAudioUploadNotifier(),
  ),
  userTracksProvider.overrideWith((ref) async => PreviewData.tracksList),
  playlistRepositoryProvider.overrideWithValue(FakePlaylistRepository()),
  playlistListNotifierProvider.overrideWith(
    (ref) => PreviewPlaylistListNotifier(),
  ),
  playlistDetailNotifierProvider.overrideWith(
    (ref, id) => PreviewPlaylistDetailNotifier(),
  ),
  playlistFormNotifierProvider.overrideWith(
    (ref) => PreviewPlaylistFormNotifier(),
  ),
  systemHealthProvider.overrideWith((ref) async => PreviewData.systemHealth),
];

/// Provides theme configuration for official Flutter `@Preview` annotations.
PreviewThemeData previewTheme() {
  return PreviewThemeData(
    materialDark: AppTheme.darkTheme,
    materialLight: AppTheme.lightTheme,
  );
}

/// Central preview scaffolding wrapper for Hums screens and widgets.
///
/// Configures:
/// 1. Isolated Riverpod [ProviderScope] with mock overrides.
/// 2. Isolated [GoRouter] with safe fallback routes so navigation does not crash.
/// 3. Standard application theme ([AppTheme.darkTheme] or [AppTheme.lightTheme]).
/// 4. Phone dimensions ([size]) to simulate realistic mobile viewports.
Widget previewApp({
  required Widget child,
  List<Override> overrides = const [],
  Brightness brightness = Brightness.dark,
  Size? size,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => child),
      GoRoute(path: '/:any*', builder: (context, state) => child),
    ],
  );

  Widget app = ProviderScope(
    overrides: [...defaultPreviewOverrides, ...overrides],
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: brightness == Brightness.dark
          ? AppTheme.darkTheme
          : AppTheme.lightTheme,
      routerConfig: router,
    ),
  );

  if (size != null) {
    app = Center(
      child: ClipRect(
        child: SizedBox(width: size.width, height: size.height, child: app),
      ),
    );
  }

  return app;
}
