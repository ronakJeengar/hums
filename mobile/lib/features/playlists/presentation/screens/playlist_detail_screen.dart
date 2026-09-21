import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/core/theme/app_icons.dart';
import 'package:hums_mobile/core/theme/app_spacing.dart';
import 'package:hums_mobile/core/theme/app_typography.dart';
import 'package:hums_mobile/core/widgets/app_icon.dart';
import 'package:hums_mobile/core/widgets/hums_app_bar.dart';
import 'package:hums_mobile/features/audio_player/domain/entities/player_queue.dart';
import 'package:hums_mobile/features/audio_player/presentation/providers/audio_player_provider.dart';
import 'package:hums_mobile/features/audio_player/presentation/widgets/mini_player.dart';
import 'package:hums_mobile/features/playlists/domain/entities/playlist_entity.dart';
import 'package:hums_mobile/features/playlists/presentation/providers/playlist_provider.dart';
import 'package:hums_mobile/features/playlists/presentation/widgets/add_track_to_playlist_modal.dart';
import 'package:hums_mobile/features/playlists/presentation/widgets/playlist_track_tile.dart';

class PlaylistDetailScreen extends ConsumerStatefulWidget {
  final String playlistId;

  const PlaylistDetailScreen({super.key, required this.playlistId});

  @override
  ConsumerState<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(playlistDetailNotifierProvider(widget.playlistId).notifier)
          .loadDetails();
    });
  }

  void _playPlaylist(PlaylistDetailEntity detail, {int startIndex = 0}) {
    final playableTracks = detail.playableTracks;
    if (playableTracks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No playable tracks in this playlist yet.'),
          backgroundColor: AppColors.surfaceElevated,
        ),
      );
      return;
    }

    final queueItems = playableTracks
        .map(
          (t) => QueueItem(
            trackId: t.trackId,
            title: t.title,
            artistName: t.artistName,
            durationSeconds: t.durationSeconds,
          ),
        )
        .toList();

    // Map startIndex from all tracks to playable index
    int actualIndex = 0;
    if (startIndex > 0 && startIndex < detail.tracks.length) {
      final selectedTrack = detail.tracks[startIndex];
      final found = queueItems.indexWhere((q) => q.trackId == selectedTrack.trackId);
      if (found >= 0) {
        actualIndex = found;
      }
    }

    final queue = PlayerQueue(
      playlistId: detail.playlist.id,
      playlistName: detail.playlist.name,
      items: queueItems,
      currentIndex: actualIndex,
    );

    ref
        .read(audioPlayerNotifierProvider.notifier)
        .playQueue(queue, startIndex: actualIndex);
  }

  void _onReorder(int oldIndex, int newIndex, PlaylistDetailEntity detail) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    if (oldIndex == newIndex) return;

    final mutableTracks = List<PlaylistTrackEntity>.from(detail.tracks);
    final moved = mutableTracks.removeAt(oldIndex);
    mutableTracks.insert(newIndex, moved);

    final reorderedTrackIds = mutableTracks.map((t) => t.trackId).toList();
    ref
        .read(playlistDetailNotifierProvider(widget.playlistId).notifier)
        .reorderTracks(reorderedTrackIds);
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Text(
          'Delete Playlist',
          style: AppTypography.headlineMedium,
        ),
        content: const Text(
          'Are you sure you want to delete this playlist? This action cannot be undone.',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final success = await ref
                  .read(playlistListNotifierProvider.notifier)
                  .deletePlaylist(widget.playlistId);
              if (mounted) {
                if (success) {
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to delete playlist'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playlistDetailNotifierProvider(widget.playlistId));
    final playerState = ref.watch(audioPlayerNotifierProvider);

    if (state.isLoading && state.detail == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: const HumsAppBar(title: 'Playlist'),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (state.hasError && state.detail == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: const HumsAppBar(title: 'Playlist'),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppIcon(
                  icon: AppIcons.error,
                  size: AppIconSizes.xl,
                  color: AppColors.error,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Failed to load playlist',
                  style: AppTypography.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  state.errorMessage ?? '',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton(
                  onPressed: () => ref
                      .read(playlistDetailNotifierProvider(widget.playlistId).notifier)
                      .loadDetails(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final detail = state.detail;
    if (detail == null) return const SizedBox.shrink();

    final playlist = detail.playlist;
    final tracks = detail.tracks;
    final currentTrackId = playerState.track?.trackId;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: HumsAppBar(
        title: playlist.name,
        leading: IconButton(
          icon: const AppIcon(
            icon: AppIcons.back,
            size: AppIconSizes.md,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const AppIcon(
              icon: AppIcons.more,
              size: AppIconSizes.md,
              color: AppColors.textPrimary,
            ),
            color: AppColors.surfaceElevated,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              side: const BorderSide(color: AppColors.border),
            ),
            onSelected: (value) {
              if (value == 'edit') {
                context.push('/playlists/${playlist.id}/edit');
              } else if (value == 'delete') {
                _confirmDelete();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    const AppIcon(
                      icon: AppIcons.edit,
                      size: AppIconSizes.sm,
                      color: AppColors.textPrimary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Edit Playlist',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const AppIcon(
                      icon: AppIcons.delete,
                      size: AppIconSizes.sm,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Delete Playlist',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surfaceElevated,
          onRefresh: () => ref
              .read(playlistDetailNotifierProvider(widget.playlistId).notifier)
              .loadDetails(),
          child: CustomScrollView(
            slivers: [
              // Header Sliver
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Cover Artwork
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        child: Container(
                          width: 160,
                          height: 160,
                          color: AppColors.surfaceHighlight,
                          child: playlist.coverImageUrl != null
                              ? Image.network(
                                  playlist.coverImageUrl!,
                                  width: 160,
                                  height: 160,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      _buildPlaceholder(),
                                )
                              : _buildPlaceholder(),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Playlist Title
                      Text(
                        playlist.name,
                        style: AppTypography.headlineLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.xxs),

                      // Metadata Subtitle
                      Text(
                        '${detail.trackCount} ${detail.trackCount == 1 ? 'track' : 'tracks'} • ${playlist.formattedDuration}',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),

                      // Description
                      if (playlist.description != null &&
                          playlist.description!.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          playlist.description!,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textTertiary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),

                      // Actions: Play All + Add Tracks
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: detail.playableTracks.isNotEmpty
                                ? () => _playPlaylist(detail)
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                                vertical: AppSpacing.sm,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppSpacing.radiusFull),
                              ),
                            ),
                            icon: const AppIcon(
                              icon: AppIcons.play,
                              size: AppIconSizes.sm,
                              color: Colors.black,
                            ),
                            label: Text(
                              'Play All',
                              style: AppTypography.labelLarge.copyWith(
                                color: Colors.black,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          OutlinedButton.icon(
                            onPressed: () {
                              final existingIds =
                                  tracks.map((t) => t.trackId).toSet();
                              SelectTrackModal.show(
                                context,
                                playlistId: widget.playlistId,
                                existingTrackIds: existingIds,
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              side: const BorderSide(color: AppColors.border),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppSpacing.radiusFull),
                              ),
                            ),
                            icon: const AppIcon(
                              icon: AppIcons.add,
                              size: AppIconSizes.sm,
                              color: AppColors.textPrimary,
                            ),
                            label: Text(
                              'Add Tracks',
                              style: AppTypography.labelLarge.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const Divider(color: AppColors.divider, height: 1),
                    ],
                  ),
                ),
              ),

              // Track List or Empty State
              if (tracks.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const AppIcon(
                            icon: AppIcons.musicNote,
                            size: AppIconSizes.xxl,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'This playlist is empty',
                            style: AppTypography.headlineMedium,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Add tracks to start building your mix.',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          ElevatedButton.icon(
                            onPressed: () {
                              final existingIds =
                                  tracks.map((t) => t.trackId).toSet();
                              SelectTrackModal.show(
                                context,
                                playlistId: widget.playlistId,
                                existingTrackIds: existingIds,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.black,
                            ),
                            icon: const AppIcon(
                              icon: AppIcons.add,
                              size: AppIconSizes.sm,
                              color: Colors.black,
                            ),
                            label: const Text('Add Tracks'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverReorderableList(
                  itemCount: tracks.length,
                  onReorder: (oldIndex, newIndex) =>
                      _onReorder(oldIndex, newIndex, detail),
                  itemBuilder: (context, index) {
                    final track = tracks[index];
                    final isPlaying = currentTrackId == track.trackId;

                    return ReorderableDelayedDragStartListener(
                      key: ValueKey(track.id),
                      index: index,
                      child: PlaylistTrackTile(
                        key: ValueKey('tile_${track.id}'),
                        track: track,
                        index: index,
                        isCurrentlyPlaying: isPlaying,
                        onTap: () => _playPlaylist(detail, startIndex: index),
                        onRemove: () async {
                          final success = await ref
                              .read(
                                playlistDetailNotifierProvider(widget.playlistId)
                                    .notifier,
                              )
                              .removeTrack(track.trackId);
                          if (context.mounted && !success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to remove track'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        },
                      ),
                    );
                  },
                ),

              // Bottom spacing for MiniPlayer
              const SliverToBoxAdapter(
                child: SizedBox(height: 80),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }

  Widget _buildPlaceholder() {
    return const Center(
      child: AppIcon(
        icon: AppIcons.playlist,
        size: AppIconSizes.xxl,
        color: AppColors.textTertiary,
      ),
    );
  }
}
