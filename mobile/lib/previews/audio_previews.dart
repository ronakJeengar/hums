import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:hums_mobile/features/audio/domain/entities/track_entity.dart';
import 'package:hums_mobile/features/audio/presentation/providers/audio_upload_provider.dart';
import 'package:hums_mobile/features/audio/presentation/screens/upload_audio_screen.dart';
import 'package:hums_mobile/features/audio/presentation/screens/user_tracks_screen.dart';
import 'package:hums_mobile/features/audio/presentation/states/audio_upload_state.dart';
import 'package:hums_mobile/previews/preview_devices.dart';
import 'package:hums_mobile/previews/preview_fakes.dart';
import 'package:hums_mobile/previews/preview_wrapper.dart';

@Preview(
  group: 'Audio & Upload',
  name: 'My Uploads - Populated',
  size: PreviewDevices.phoneStandard,
)
Widget userTracksPopulatedPreview() {
  return previewApp(child: const UserTracksScreen());
}

@Preview(
  group: 'Audio & Upload',
  name: 'My Uploads - Empty State',
  size: PreviewDevices.phoneStandard,
)
Widget userTracksEmptyPreview() {
  return previewApp(
    overrides: [
      userTracksProvider.overrideWith((ref) async => <TrackEntity>[]),
    ],
    child: const UserTracksScreen(),
  );
}

@Preview(
  group: 'Audio & Upload',
  name: 'My Uploads - Loading',
  size: PreviewDevices.phoneStandard,
)
Widget userTracksLoadingPreview() {
  return previewApp(
    overrides: [
      userTracksProvider.overrideWith(
        (ref) => Completer<List<TrackEntity>>().future,
      ),
    ],
    child: const UserTracksScreen(),
  );
}

@Preview(
  group: 'Audio & Upload',
  name: 'Upload Audio - Form',
  size: PreviewDevices.phoneStandard,
)
Widget uploadAudioInitialPreview() {
  return previewApp(child: const UploadAudioScreen());
}

@Preview(
  group: 'Audio & Upload',
  name: 'Upload Audio - File Selected',
  size: PreviewDevices.phoneStandard,
)
Widget uploadAudioFileSelectedPreview() {
  return previewApp(
    overrides: [
      audioUploadNotifierProvider.overrideWith(
        (ref) => PreviewAudioUploadNotifier(
          const AudioUploadState.fileSelected(
            filePath: '/storage/emulated/0/Music/midnight_resonance.wav',
            fileName: 'midnight_resonance.wav',
            fileSizeBytes: 24500000,
          ),
        ),
      ),
    ],
    child: const UploadAudioScreen(),
  );
}

@Preview(
  group: 'Audio & Upload',
  name: 'Upload Audio - Uploading (45%)',
  size: PreviewDevices.phoneStandard,
)
Widget uploadAudioUploadingPreview() {
  return previewApp(
    overrides: [
      audioUploadNotifierProvider.overrideWith(
        (ref) => PreviewAudioUploadNotifier(
          const AudioUploadState.uploading(
            filePath: '/storage/emulated/0/Music/midnight_resonance.wav',
            fileName: 'midnight_resonance.wav',
            fileSizeBytes: 24500000,
            progress: 0.45,
          ),
        ),
      ),
    ],
    child: const UploadAudioScreen(),
  );
}

@Preview(
  group: 'Audio & Upload',
  name: 'Upload Audio - Error State',
  size: PreviewDevices.phoneStandard,
)
Widget uploadAudioFailurePreview() {
  return previewApp(
    overrides: [
      audioUploadNotifierProvider.overrideWith(
        (ref) => PreviewAudioUploadNotifier(
          const AudioUploadState.failure(
            'Failed to upload audio: connection timed out.',
            code: 'TIMEOUT',
            filePath: '/storage/emulated/0/Music/midnight_resonance.wav',
            fileName: 'midnight_resonance.wav',
            fileSizeBytes: 24500000,
          ),
        ),
      ),
    ],
    child: const UploadAudioScreen(),
  );
}
