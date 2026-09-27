import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/core/theme/app_spacing.dart';
import 'package:hums_mobile/core/theme/app_typography.dart';
import 'package:hums_mobile/features/audio_player/domain/entities/player_queue.dart';
import 'package:hums_mobile/features/audio_player/presentation/providers/audio_player_provider.dart';
import 'package:hums_mobile/features/audio_player/presentation/widgets/mini_player.dart';
import 'package:hums_mobile/features/downloads/presentation/widgets/download_button.dart';
import 'package:hums_mobile/features/library/domain/entities/liked_track_entity.dart';
import 'package:hums_mobile/features/library/presentation/providers/library_provider.dart';
import 'package:hums_mobile/features/library/presentation/providers/like_notifier.dart';
import 'package:hums_mobile/features/library/presentation/widgets/like_button.dart';
import 'package:hums_mobile/features/playlists/presentation/widgets/add_track_to_playlist_modal.dart';
import 'package:hums_mobile/routing/route_names.dart';

class LikedSongsScreen extends ConsumerStatefulWidget {
  const LikedSongsScreen({super.key});

  @override
  ConsumerState<LikedSongsScreen> createState() => _LikedSongsScreenState();
}

class _LikedSongsScreenState extends ConsumerState<LikedSongsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(likedTracksNotifierProvider.notifier).loadNextPage();
    }
  }

  void _playQueue(List<LikedTrackEntity> tracks, int startIndex) {
    if (tracks.isEmpty) return;

    final queueItems = tracks
        .map(
          (t) => QueueItem(
            trackId: t.id,
            title: t.title,
            artistName: t.artistName ?? 'Unknown Artist',
            albumName: t.albumName,
            durationSeconds: t.durationSeconds,
          ),
        )
        .toList();

    final queue = PlayerQueue(
      playlistId: 'liked_songs',
      playlistName: 'Liked Songs',
      items: queueItems,
      currentIndex: startIndex,
    );

    ref.read(audioPlayerNotifierProvider.notifier).playQueue(
          queue,
          startIndex: startIndex,
        );
  }

  void _showTrackMenu(BuildContext context, LikedTrackEntity track) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusMd)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHighlight,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                      child: const Icon(Icons.music_note_rounded, color: AppColors.primary),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            style: AppTypography.titleMedium.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            track.artistName ?? 'Unknown Artist',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: AppColors.divider, height: 1),
              ListTile(
                leading: const Icon(Icons.playlist_add_rounded, color: AppColors.textPrimary),
                title: Text(
                  'Add to playlist',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                ),
                onTap: () {
                  Navigator.of(bottomSheetContext).pop();
                  AddToPlaylistModal.show(
                    context,
                    trackId: track.id,
                    trackTitle: track.title,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.favorite_border_rounded, color: AppColors.error),
                title: Text(
                  'Remove from Liked Songs',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.error),
                ),
                onTap: () {
                  Navigator.of(bottomSheetContext).pop();
                  ref.read(likeNotifierProvider(track.id).notifier).toggleLike();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(likedTracksNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // 1. App Bar
              SliverAppBar(
                pinned: true,
                backgroundColor: AppColors.surface,
                leading: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: AppColors.textPrimary,
                    size: 20,
                  ),
                  onPressed: () => context.pop(),
                ),
                title: Text(
                  'Liked Songs',
                  style: AppTypography.headlineMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // 2. Hero Header Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE5484D), Color(0xFFB82830)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.error.withValues(alpha: 0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.favorite_rounded,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Liked Songs',
                              style: AppTypography.displayMedium.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              '${state.tracks.length} ${state.tracks.length == 1 ? "song" : "songs"}',
                              style: AppTypography.labelLarge.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            if (state.tracks.isNotEmpty)
                              ElevatedButton.icon(
                                onPressed: () => _playQueue(state.tracks, 0),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: AppSpacing.xs,
                                  ),
                                ),
                                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                                label: const Text('Play All'),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Content States
              if (state.isLoading && state.tracks.isEmpty) ...[
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
              ] else if (state.errorMessage != null && state.tracks.isEmpty) ...[
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 48,
                            color: AppColors.error,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            state.errorMessage!,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          ElevatedButton(
                            onPressed: () {
                              ref.read(likedTracksNotifierProvider.notifier).refresh();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ] else if (state.tracks.isEmpty) ...[
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.favorite_border_rounded,
                            size: 64,
                            color: AppColors.textTertiary.withValues(alpha: 0.6),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            "No liked songs yet.",
                            style: AppTypography.headlineMedium.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            "Tap ❤️ on songs you love and they'll appear here.",
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          ElevatedButton(
                            onPressed: () => context.push(RouteNames.searchPath),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                            ),
                            child: const Text('Discover Music'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ] else ...[
                // Track list
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final track = state.tracks[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.xxs,
                        ),
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceHighlight,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: AppTypography.labelLarge.copyWith(
                                color: AppColors.textTertiary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.titleMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          '${track.artistName ?? "Unknown Artist"} • ${track.formattedDuration}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            LikeButton(
                              trackId: track.id,
                              initialLiked: true,
                              initialCount: track.likesCount,
                              trackTitle: track.title,
                            ),
                            DownloadButton(
                              trackId: track.id,
                              title: track.title,
                              artistName: track.artistName,
                              albumName: track.albumName,
                              durationSeconds: track.durationSeconds,
                              size: 20,
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.more_vert_rounded,
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _showTrackMenu(context, track),
                            ),
                          ],
                        ),
                        onTap: () => _playQueue(state.tracks, index),
                      );
                    },
                    childCount: state.tracks.length,
                  ),
                ),

                if (state.isFetchingNextPage) ...[
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.md),
                      child: Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                    ),
                  ),
                ],

                // Space for floating MiniPlayer
                const SliverToBoxAdapter(
                  child: SizedBox(height: 100),
                ),
              ],
            ],
          ),

          // 4. Floating MiniPlayer at bottom
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: MiniPlayer(),
          ),
        ],
      ),
    );
  }
}
