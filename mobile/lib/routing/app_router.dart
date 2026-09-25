import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hums_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:hums_mobile/features/auth/presentation/states/auth_state.dart';
import 'package:hums_mobile/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:hums_mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:hums_mobile/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:hums_mobile/features/auth/presentation/screens/signup_screen.dart';
import 'package:hums_mobile/features/common/presentation/screens/error_screen.dart';
import 'package:hums_mobile/features/common/presentation/screens/home_screen.dart';
import 'package:hums_mobile/features/common/presentation/screens/splash_screen.dart';
import 'package:hums_mobile/features/audio/presentation/screens/upload_audio_screen.dart';
import 'package:hums_mobile/features/audio/presentation/screens/user_tracks_screen.dart';
import 'package:hums_mobile/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:hums_mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:hums_mobile/features/audio_player/presentation/screens/full_player_screen.dart';
import 'package:hums_mobile/features/playlists/presentation/screens/create_playlist_screen.dart';
import 'package:hums_mobile/features/playlists/presentation/screens/edit_playlist_screen.dart';
import 'package:hums_mobile/features/playlists/presentation/screens/playlist_detail_screen.dart';
import 'package:hums_mobile/features/playlists/presentation/screens/playlist_list_screen.dart';
import 'package:hums_mobile/features/downloads/presentation/screens/downloads_screen.dart';
import 'package:hums_mobile/routing/route_names.dart';

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen<AuthState>(authNotifierProvider, (previous, next) {
      notifyListeners();
    });
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(authNotifierProvider);
    final isAuth = authState.isAuthenticated;

    final currentLoc = state.matchedLocation;
    final isSplash = currentLoc == RouteNames.splashPath;
    final isAuthRoute = currentLoc == RouteNames.loginPath ||
        currentLoc == RouteNames.registerPath ||
        currentLoc == RouteNames.forgotPasswordPath ||
        currentLoc == RouteNames.resetPasswordPath;

    // Allow splash screen to execute its transition
    if (isSplash) return null;

    // If authenticated and trying to access auth pages, redirect to Home
    if (isAuth && isAuthRoute) {
      return RouteNames.homePath;
    }

    // If unauthenticated and trying to access protected pages, redirect to Login
    if (!isAuth && !isAuthRoute) {
      return RouteNames.loginPath;
    }

    return null;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = RouterNotifier(ref);

  return GoRouter(
    initialLocation: RouteNames.splashPath,
    debugLogDiagnostics: false,
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(
        name: RouteNames.splash,
        path: RouteNames.splashPath,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        name: RouteNames.login,
        path: RouteNames.loginPath,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        name: RouteNames.register,
        path: RouteNames.registerPath,
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        name: RouteNames.forgotPassword,
        path: RouteNames.forgotPasswordPath,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        name: RouteNames.resetPassword,
        path: RouteNames.resetPasswordPath,
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      GoRoute(
        name: RouteNames.home,
        path: RouteNames.homePath,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        name: RouteNames.profile,
        path: RouteNames.profilePath,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        name: RouteNames.editProfile,
        path: RouteNames.editProfilePath,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        name: RouteNames.uploadAudio,
        path: RouteNames.uploadAudioPath,
        builder: (context, state) => const UploadAudioScreen(),
      ),
      GoRoute(
        name: RouteNames.userTracks,
        path: RouteNames.userTracksPath,
        builder: (context, state) => const UserTracksScreen(),
      ),
      GoRoute(
        name: RouteNames.player,
        path: RouteNames.playerPath,
        builder: (context, state) => const FullPlayerScreen(),
      ),
      GoRoute(
        name: RouteNames.playlists,
        path: RouteNames.playlistsPath,
        builder: (context, state) => const PlaylistListScreen(),
      ),
      GoRoute(
        name: RouteNames.createPlaylist,
        path: RouteNames.createPlaylistPath,
        builder: (context, state) => const CreatePlaylistScreen(),
      ),
      GoRoute(
        name: RouteNames.playlistDetail,
        path: RouteNames.playlistDetailPath,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return PlaylistDetailScreen(playlistId: id);
        },
      ),
      GoRoute(
        name: RouteNames.editPlaylist,
        path: RouteNames.editPlaylistPath,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return EditPlaylistScreen(playlistId: id);
        },
      ),
      GoRoute(
        name: RouteNames.downloads,
        path: RouteNames.downloadsPath,
        builder: (context, state) => const DownloadsScreen(),
      ),
    ],
    errorBuilder: (context, state) => ErrorScreen(
      message: state.error?.message,
    ),
  );
});
