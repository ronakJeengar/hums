import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hums_mobile/features/audio/presentation/screens/user_tracks_screen.dart';
import 'package:hums_mobile/features/audio_player/presentation/screens/full_player_screen.dart';
import 'package:hums_mobile/features/audio_player/presentation/widgets/mini_player.dart';
import 'package:hums_mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:hums_mobile/features/common/presentation/screens/error_screen.dart';
import 'package:hums_mobile/features/common/presentation/screens/home_screen.dart';
import 'package:hums_mobile/features/common/presentation/screens/splash_screen.dart';
import 'package:hums_mobile/features/playlists/presentation/screens/playlist_list_screen.dart';
import 'package:hums_mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:hums_mobile/previews/screen_previews.dart';

void main() {
  group('Preview System Infrastructure', () {
    test('PreviewDevices dimensions are defined accurately', () {
      expect(PreviewDevices.phoneStandard.width, 393);
      expect(PreviewDevices.phoneStandard.height, 852);
      expect(PreviewDevices.phoneSmall.width, 360);
      expect(PreviewDevices.phoneSmall.height, 780);
      expect(PreviewDevices.phoneLarge.width, 430);
      expect(PreviewDevices.phoneLarge.height, 932);
    });

    test('PreviewData contains valid fixture models', () {
      expect(PreviewData.user.name, 'Elena Rostova');
      expect(PreviewData.profile.bio, isNotEmpty);
      expect(PreviewData.tracksList.length, 5);
      expect(PreviewData.playlistsList.length, 2);
      expect(PreviewData.playerPlaying.isPlaying, isTrue);
      expect(PreviewData.playerPaused.isPaused, isTrue);
      expect(PreviewData.playerError.isError, isTrue);
      expect(PreviewData.systemHealth['status'], 'healthy');
    });

    testWidgets('previewApp wrapper renders child without throwing', (
      tester,
    ) async {
      await tester.pumpWidget(
        previewApp(
          child: const Scaffold(body: Center(child: Text('Preview Test App'))),
        ),
      );

      expect(find.text('Preview Test App'), findsOneWidget);
    });
  });

  group('Authentication Previews', () {
    testWidgets('loginPreview renders LoginScreen with form fields', (
      tester,
    ) async {
      await tester.pumpWidget(loginPreview());
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('Sign In'), findsWidgets);
    });

    testWidgets('loginErrorPreview renders LoginScreen with error banner', (
      tester,
    ) async {
      await tester.pumpWidget(loginErrorPreview());
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(
        find.text('Invalid email or password combination.'),
        findsOneWidget,
      );
    });

    testWidgets('signupPreview renders SignupScreen', (tester) async {
      await tester.pumpWidget(signupPreview());
      await tester.pumpAndSettle();

      expect(find.text('Create Account'), findsWidgets);
    });

    testWidgets('forgotPasswordPreview renders ForgotPasswordScreen', (
      tester,
    ) async {
      await tester.pumpWidget(forgotPasswordPreview());
      await tester.pumpAndSettle();

      expect(find.text('Reset Password'), findsWidgets);
    });

    testWidgets('resetPasswordPreview renders ResetPasswordScreen', (
      tester,
    ) async {
      await tester.pumpWidget(resetPasswordPreview());
      await tester.pumpAndSettle();

      expect(find.text('New Password'), findsWidgets);
      expect(find.text('Reset Password'), findsWidgets);
    });
  });

  group('Home Previews', () {
    testWidgets(
      'homePopulatedPreview renders HomeScreen with welcome message',
      (tester) async {
        await tester.pumpWidget(homePopulatedPreview());
        await tester.pumpAndSettle();

        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.text('Welcome, Elena Rostova'), findsOneWidget);
      },
    );

    testWidgets('homeGuestPreview renders HomeScreen in guest state', (
      tester,
    ) async {
      await tester.pumpWidget(homeGuestPreview());
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Welcome to Hums'), findsOneWidget);
    });

    testWidgets('homeLightPreview renders HomeScreen in light brightness', (
      tester,
    ) async {
      await tester.pumpWidget(homeLightPreview());
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });

  group('Audio Player Previews', () {
    testWidgets(
      'fullPlayerPlayingPreview renders FullPlayerScreen with track title',
      (tester) async {
        await tester.pumpWidget(fullPlayerPlayingPreview());
        await tester.pumpAndSettle();

        expect(find.byType(FullPlayerScreen), findsOneWidget);
        expect(find.text('Midnight Resonance'), findsOneWidget);
        expect(find.text('Elena Rostova'), findsWidgets);
      },
    );

    testWidgets('fullPlayerPausedPreview renders FullPlayerScreen', (
      tester,
    ) async {
      await tester.pumpWidget(fullPlayerPausedPreview());
      await tester.pumpAndSettle();

      expect(find.byType(FullPlayerScreen), findsOneWidget);
      expect(find.text('Midnight Resonance'), findsOneWidget);
    });

    testWidgets('fullPlayerIdlePreview renders FullPlayerScreen idle state', (
      tester,
    ) async {
      await tester.pumpWidget(fullPlayerIdlePreview());
      await tester.pumpAndSettle();

      expect(find.byType(FullPlayerScreen), findsOneWidget);
      expect(find.text('No track currently playing'), findsOneWidget);
    });

    testWidgets(
      'miniPlayerPlayingPreview renders MiniPlayer with active track',
      (tester) async {
        await tester.pumpWidget(miniPlayerPlayingPreview());
        await tester.pumpAndSettle();

        expect(find.byType(MiniPlayer), findsOneWidget);
        expect(find.text('Midnight Resonance'), findsOneWidget);
      },
    );
  });

  group('Audio & Upload Previews', () {
    testWidgets(
      'userTracksPopulatedPreview renders UserTracksScreen with items',
      (tester) async {
        await tester.pumpWidget(userTracksPopulatedPreview());
        await tester.pumpAndSettle();

        expect(find.byType(UserTracksScreen), findsOneWidget);
        expect(find.text('Midnight Resonance'), findsOneWidget);
        expect(find.text('Cedar Smoke'), findsOneWidget);
      },
    );

    testWidgets(
      'userTracksEmptyPreview renders UserTracksScreen with empty prompt',
      (tester) async {
        await tester.pumpWidget(userTracksEmptyPreview());
        await tester.pumpAndSettle();

        expect(find.byType(UserTracksScreen), findsOneWidget);
        expect(find.text('No Tracks Uploaded Yet'), findsOneWidget);
      },
    );

    testWidgets('uploadAudioInitialPreview renders UploadAudioScreen', (
      tester,
    ) async {
      await tester.pumpWidget(uploadAudioInitialPreview());
      await tester.pumpAndSettle();

      expect(find.text('Upload Audio'), findsWidgets);
    });
  });

  group('Playlist Previews', () {
    testWidgets(
      'playlistListPopulatedPreview renders PlaylistListScreen with playlists',
      (tester) async {
        await tester.pumpWidget(playlistListPopulatedPreview());
        await tester.pumpAndSettle();

        expect(find.byType(PlaylistListScreen), findsOneWidget);
        expect(find.text('Late Night Focus'), findsOneWidget);
        expect(find.text('Analog Warmth'), findsOneWidget);
      },
    );

    testWidgets(
      'playlistListEmptyPreview renders PlaylistListScreen empty state',
      (tester) async {
        await tester.pumpWidget(playlistListEmptyPreview());
        await tester.pumpAndSettle();

        expect(find.byType(PlaylistListScreen), findsOneWidget);
        expect(find.text('No playlists yet'), findsOneWidget);
      },
    );

    testWidgets('createPlaylistPreview renders CreatePlaylistScreen', (
      tester,
    ) async {
      await tester.pumpWidget(createPlaylistPreview());
      await tester.pumpAndSettle();

      expect(find.text('Create Playlist'), findsWidgets);
    });
  });

  group('Profile & Common Previews', () {
    testWidgets(
      'profileInitialsPreview renders ProfileScreen with initials and details',
      (tester) async {
        await tester.pumpWidget(profileInitialsPreview());
        await tester.pumpAndSettle();

        expect(find.byType(ProfileScreen), findsOneWidget);
        expect(find.text('Elena Rostova'), findsWidgets);
        expect(find.text('ER'), findsOneWidget);
        expect(find.text('elena.rostova@example.com'), findsOneWidget);
      },
    );

    testWidgets('splashPreview renders SplashScreen', (tester) async {
      await tester.pumpWidget(splashPreview());
      expect(find.byType(SplashScreen), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpAndSettle();
    });

    testWidgets('errorDefaultPreview renders ErrorScreen', (tester) async {
      await tester.pumpWidget(errorDefaultPreview());
      await tester.pumpAndSettle();

      expect(find.byType(ErrorScreen), findsOneWidget);
      expect(find.text('Something went wrong'), findsOneWidget);
    });
  });
}
