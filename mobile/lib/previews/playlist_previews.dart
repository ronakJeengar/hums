import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:hums_mobile/features/playlists/presentation/providers/playlist_provider.dart';
import 'package:hums_mobile/features/playlists/presentation/screens/create_playlist_screen.dart';
import 'package:hums_mobile/features/playlists/presentation/screens/edit_playlist_screen.dart';
import 'package:hums_mobile/features/playlists/presentation/screens/playlist_detail_screen.dart';
import 'package:hums_mobile/features/playlists/presentation/screens/playlist_list_screen.dart';
import 'package:hums_mobile/features/playlists/presentation/states/playlist_state.dart';
import 'package:hums_mobile/features/playlists/presentation/widgets/add_track_to_playlist_modal.dart';
import 'package:hums_mobile/previews/preview_data.dart';
import 'package:hums_mobile/previews/preview_devices.dart';
import 'package:hums_mobile/previews/preview_fakes.dart';
import 'package:hums_mobile/previews/preview_wrapper.dart';

@Preview(
  group: 'Playlists',
  name: 'Playlist List - Populated',
  size: PreviewDevices.phoneStandard,
)
Widget playlistListPopulatedPreview() {
  return previewApp(child: const PlaylistListScreen());
}

@Preview(
  group: 'Playlists',
  name: 'Playlist List - Empty State',
  size: PreviewDevices.phoneStandard,
)
Widget playlistListEmptyPreview() {
  return previewApp(
    overrides: [
      playlistListNotifierProvider.overrideWith(
        (ref) => PreviewPlaylistListNotifier(
          const PlaylistListState(
            status: PlaylistListStatus.loaded,
            playlists: [],
          ),
        ),
      ),
    ],
    child: const PlaylistListScreen(),
  );
}

@Preview(
  group: 'Playlists',
  name: 'Playlist List - Loading',
  size: PreviewDevices.phoneStandard,
)
Widget playlistListLoadingPreview() {
  return previewApp(
    overrides: [
      playlistListNotifierProvider.overrideWith(
        (ref) => PreviewPlaylistListNotifier(
          const PlaylistListState(status: PlaylistListStatus.loading),
        ),
      ),
    ],
    child: const PlaylistListScreen(),
  );
}

@Preview(
  group: 'Playlists',
  name: 'Playlist Detail - Populated',
  size: PreviewDevices.phoneStandard,
)
Widget playlistDetailPopulatedPreview() {
  return previewApp(
    child: const PlaylistDetailScreen(playlistId: 'pl_preview_1'),
  );
}

@Preview(
  group: 'Playlists',
  name: 'Playlist Detail - Empty State',
  size: PreviewDevices.phoneStandard,
)
Widget playlistDetailEmptyPreview() {
  return previewApp(
    overrides: [
      playlistDetailNotifierProvider.overrideWith(
        (ref, id) => PreviewPlaylistDetailNotifier(
          PlaylistDetailState(
            status: PlaylistDetailStatus.loaded,
            detail: PreviewData.playlistDetailEmpty,
          ),
        ),
      ),
    ],
    child: const PlaylistDetailScreen(playlistId: 'pl_empty_1'),
  );
}

@Preview(
  group: 'Playlists',
  name: 'Playlist Detail - Loading',
  size: PreviewDevices.phoneStandard,
)
Widget playlistDetailLoadingPreview() {
  return previewApp(
    overrides: [
      playlistDetailNotifierProvider.overrideWith(
        (ref, id) => PreviewPlaylistDetailNotifier(
          const PlaylistDetailState(status: PlaylistDetailStatus.loading),
        ),
      ),
    ],
    child: const PlaylistDetailScreen(playlistId: 'pl_preview_1'),
  );
}

@Preview(
  group: 'Playlists',
  name: 'Create Playlist - Form',
  size: PreviewDevices.phoneStandard,
)
Widget createPlaylistPreview() {
  return previewApp(child: const CreatePlaylistScreen());
}

@Preview(
  group: 'Playlists',
  name: 'Edit Playlist - Form',
  size: PreviewDevices.phoneStandard,
)
Widget editPlaylistPreview() {
  return previewApp(
    child: const EditPlaylistScreen(playlistId: 'pl_preview_1'),
  );
}

@Preview(
  group: 'Playlists',
  name: 'Select Track Modal',
  size: PreviewDevices.phoneStandard,
)
Widget selectTrackModalPreview() {
  return previewApp(
    child: const Scaffold(
      body: SizedBox.expand(
        child: SelectTrackModal(
          playlistId: 'pl_preview_1',
          existingTrackIds: {'trk_preview_1'},
        ),
      ),
    ),
  );
}

@Preview(
  group: 'Playlists',
  name: 'Add To Playlist Modal',
  size: PreviewDevices.phoneStandard,
)
Widget addToPlaylistModalPreview() {
  return previewApp(
    child: const Scaffold(
      body: SizedBox.expand(
        child: AddToPlaylistModal(
          trackId: 'trk_preview_1',
          trackTitle: 'Midnight Resonance',
        ),
      ),
    ),
  );
}
