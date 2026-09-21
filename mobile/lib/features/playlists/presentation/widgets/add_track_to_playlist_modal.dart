import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/core/theme/app_icons.dart';
import 'package:hums_mobile/core/theme/app_spacing.dart';
import 'package:hums_mobile/core/theme/app_typography.dart';
import 'package:hums_mobile/core/widgets/app_icon.dart';
import 'package:hums_mobile/features/audio/presentation/providers/audio_upload_provider.dart';
import 'package:hums_mobile/features/playlists/presentation/providers/playlist_provider.dart';

/// Modal to select an existing user track to add to the given playlist
class SelectTrackModal extends ConsumerWidget {
  final String playlistId;
  final Set<String> existingTrackIds;
  final Function(String trackId)? onTrackAdded;

  const SelectTrackModal({
    super.key,
    required this.playlistId,
    required this.existingTrackIds,
    this.onTrackAdded,
  });

  static Future<void> show(
    BuildContext context, {
    required String playlistId,
    required Set<String> existingTrackIds,
    Function(String trackId)? onTrackAdded,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
      ),
      builder: (context) => SelectTrackModal(
        playlistId: playlistId,
        existingTrackIds: existingTrackIds,
        onTrackAdded: onTrackAdded,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracksAsync = ref.watch(userTracksProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceHighlight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Add Tracks to Playlist',
                    style: AppTypography.headlineMedium,
                  ),
                  IconButton(
                    icon: const AppIcon(
                      icon: AppIcons.close,
                      size: AppIconSizes.md,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.divider, height: 1),
            // Content
            Expanded(
              child: tracksAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      'Failed to load tracks: $err',
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                data: (tracks) {
                  if (tracks.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const AppIcon(
                              icon: AppIcons.musicNote,
                              size: AppIconSizes.xl,
                              color: AppColors.textTertiary,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'No tracks uploaded yet',
                              style: AppTypography.titleMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Upload tracks first to add them to your playlist.',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textTertiary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: tracks.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSpacing.xs),
                    itemBuilder: (context, index) {
                      final track = tracks[index];
                      final isAlreadyAdded = existingTrackIds.contains(track.id);

                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        tileColor: AppColors.surface,
                        title: Text(
                          track.title,
                          style: AppTypography.bodyLarge.copyWith(
                            color: isAlreadyAdded
                                ? AppColors.textTertiary
                                : AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          track.artistName ?? 'Unknown Artist',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textTertiary,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: isAlreadyAdded
                            ? Text(
                                'Added',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.textTertiary,
                                  fontSize: 12,
                                ),
                              )
                            : const AppIcon(
                                icon: AppIcons.add,
                                size: AppIconSizes.md,
                                color: AppColors.primary,
                              ),
                        onTap: isAlreadyAdded
                            ? null
                            : () async {
                                final notifier = ref.read(
                                  playlistDetailNotifierProvider(playlistId).notifier,
                                );
                                final success = await notifier.addTrack(track.id);
                                if (context.mounted) {
                                  if (success) {
                                    onTrackAdded?.call(track.id);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Added "${track.title}" to playlist'),
                                        backgroundColor: AppColors.surfaceElevated,
                                      ),
                                    );
                                    Navigator.of(context).pop();
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Failed to add track to playlist'),
                                        backgroundColor: AppColors.error,
                                      ),
                                    );
                                  }
                                }
                              },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Modal to select a playlist to add a specific track to
class AddToPlaylistModal extends ConsumerWidget {
  final String trackId;
  final String trackTitle;

  const AddToPlaylistModal({
    super.key,
    required this.trackId,
    required this.trackTitle,
  });

  static Future<void> show(
    BuildContext context, {
    required String trackId,
    required String trackTitle,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
      ),
      builder: (context) => AddToPlaylistModal(
        trackId: trackId,
        trackTitle: trackTitle,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistListState = ref.watch(playlistListNotifierProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceHighlight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add to Playlist',
                          style: AppTypography.headlineMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          trackTitle,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const AppIcon(
                      icon: AppIcons.close,
                      size: AppIconSizes.md,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.divider, height: 1),
            // Content
            Expanded(
              child: playlistListState.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    )
                  : playlistListState.playlists.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.xl),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const AppIcon(
                                  icon: AppIcons.playlist,
                                  size: AppIconSizes.xl,
                                  color: AppColors.textTertiary,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Text(
                                  'No playlists created yet',
                                  style: AppTypography.titleMedium.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.all(AppSpacing.md),
                          itemCount: playlistListState.playlists.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: AppSpacing.xs),
                          itemBuilder: (context, index) {
                            final playlist = playlistListState.playlists[index];

                            return ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppSpacing.radiusSm),
                                side: const BorderSide(color: AppColors.border),
                              ),
                              tileColor: AppColors.surface,
                              leading: const AppIcon(
                                icon: AppIcons.playlist,
                                size: AppIconSizes.md,
                                color: AppColors.primary,
                              ),
                              title: Text(
                                playlist.name,
                                style: AppTypography.bodyLarge,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${playlist.trackCount} tracks',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.textTertiary,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: const AppIcon(
                                icon: AppIcons.add,
                                size: AppIconSizes.md,
                                color: AppColors.primary,
                              ),
                              onTap: () async {
                                final notifier = ref.read(
                                  playlistDetailNotifierProvider(playlist.id).notifier,
                                );
                                final success = await notifier.addTrack(trackId);
                                if (context.mounted) {
                                  if (success) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Added to "${playlist.name}"',
                                        ),
                                        backgroundColor: AppColors.surfaceElevated,
                                      ),
                                    );
                                    Navigator.of(context).pop();
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Track already in playlist or failed to add',
                                        ),
                                        backgroundColor: AppColors.error,
                                      ),
                                    );
                                  }
                                }
                              },
                            );
                          },
                        ),
            ),
          ],
        );
      },
    );
  }
}
