import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:hums_mobile/features/audio_player/presentation/providers/audio_player_provider.dart';
import 'package:hums_mobile/features/audio_player/presentation/screens/full_player_screen.dart';
import 'package:hums_mobile/features/audio_player/presentation/widgets/mini_player.dart';
import 'package:hums_mobile/previews/preview_data.dart';
import 'package:hums_mobile/previews/preview_devices.dart';
import 'package:hums_mobile/previews/preview_fakes.dart';
import 'package:hums_mobile/previews/preview_wrapper.dart';

@Preview(
  group: 'Player',
  name: 'Full Player - Playing',
  size: PreviewDevices.phoneStandard,
)
Widget fullPlayerPlayingPreview() {
  return previewApp(
    overrides: [
      audioPlayerNotifierProvider.overrideWith(
        (ref) => PreviewAudioPlayerNotifier(PreviewData.playerPlaying),
      ),
    ],
    child: const FullPlayerScreen(),
  );
}

@Preview(
  group: 'Player',
  name: 'Full Player - Paused',
  size: PreviewDevices.phoneStandard,
)
Widget fullPlayerPausedPreview() {
  return previewApp(
    overrides: [
      audioPlayerNotifierProvider.overrideWith(
        (ref) => PreviewAudioPlayerNotifier(PreviewData.playerPaused),
      ),
    ],
    child: const FullPlayerScreen(),
  );
}

@Preview(
  group: 'Player',
  name: 'Full Player - Buffering',
  size: PreviewDevices.phoneStandard,
)
Widget fullPlayerBufferingPreview() {
  return previewApp(
    overrides: [
      audioPlayerNotifierProvider.overrideWith(
        (ref) => PreviewAudioPlayerNotifier(PreviewData.playerBuffering),
      ),
    ],
    child: const FullPlayerScreen(),
  );
}

@Preview(
  group: 'Player',
  name: 'Full Player - Idle / No Track',
  size: PreviewDevices.phoneStandard,
)
Widget fullPlayerIdlePreview() {
  return previewApp(
    overrides: [
      audioPlayerNotifierProvider.overrideWith(
        (ref) => PreviewAudioPlayerNotifier(PreviewData.playerIdle),
      ),
    ],
    child: const FullPlayerScreen(),
  );
}

@Preview(
  group: 'Player',
  name: 'Full Player - Error State',
  size: PreviewDevices.phoneStandard,
)
Widget fullPlayerErrorPreview() {
  return previewApp(
    overrides: [
      audioPlayerNotifierProvider.overrideWith(
        (ref) => PreviewAudioPlayerNotifier(PreviewData.playerError),
      ),
    ],
    child: const FullPlayerScreen(),
  );
}

@Preview(
  group: 'Player',
  name: 'Mini Player - Playing',
  size: PreviewDevices.phoneStandard,
)
Widget miniPlayerPlayingPreview() {
  return previewApp(
    overrides: [
      audioPlayerNotifierProvider.overrideWith(
        (ref) => PreviewAudioPlayerNotifier(PreviewData.playerPlaying),
      ),
    ],
    child: const Scaffold(
      body: Center(
        child: Text(
          'Sample Screen Content',
          style: TextStyle(color: Colors.white70),
        ),
      ),
      bottomNavigationBar: MiniPlayer(),
    ),
  );
}

@Preview(
  group: 'Player',
  name: 'Mini Player - Paused',
  size: PreviewDevices.phoneStandard,
)
Widget miniPlayerPausedPreview() {
  return previewApp(
    overrides: [
      audioPlayerNotifierProvider.overrideWith(
        (ref) => PreviewAudioPlayerNotifier(PreviewData.playerPaused),
      ),
    ],
    child: const Scaffold(
      body: Center(
        child: Text(
          'Sample Screen Content',
          style: TextStyle(color: Colors.white70),
        ),
      ),
      bottomNavigationBar: MiniPlayer(),
    ),
  );
}
