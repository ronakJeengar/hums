import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/core/theme/app_radii.dart';
import 'package:hums_mobile/core/theme/app_spacing.dart';
import 'package:hums_mobile/core/theme/app_typography.dart';
import 'package:hums_mobile/core/widgets/hums_button.dart';
import 'package:hums_mobile/core/widgets/hums_empty_state.dart';
import 'package:hums_mobile/core/widgets/hums_track_tile.dart';
import 'package:hums_mobile/features/audio_player/domain/entities/player_queue.dart';
import 'package:hums_mobile/features/audio_player/presentation/providers/audio_player_provider.dart';
import 'package:hums_mobile/features/audio_player/presentation/widgets/mini_player.dart';
import 'package:hums_mobile/features/downloads/presentation/widgets/download_button.dart';
import 'package:hums_mobile/features/library/domain/entities/liked_track_entity.dart';
import 'package:hums_mobile/features/library/presentation/providers/library_provider.dart';
import 'package:hums_mobile/features/library/presentation/providers/like_notifier.dart';
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xxl)),
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
                        borderRadius: BorderRadius.circular(AppRadii.sm),
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
    final playerState = ref.watch(audioPlayerNotifierProvider);
    final currentPlayingTrackId = playerState.track?.trackId;

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
                backgroundColor: AppColors.background,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: AppColors.textPrimary,
                    size: 20,
                  ),
                  onPressed: () => context.pop(),
                ),
                title: const Text(
                  'Liked Songs',
                  style: AppTypography.headlineLarge,
                ),
              ),

              // 2. Hero Header Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE5484D), Color(0xFF7A1C20)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(AppRadii.xl),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE5484D).withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(AppRadii.lg),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.favorite_rounded,
                              color: Colors.white,
                              size: 44,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Liked Songs',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${state.tracks.length} ${state.tracks.length == 1 ? "track" : "tracks"} saved',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              if (state.tracks.isNotEmpty)
                                HumsButton(
                                  label: 'Play All',
                                  icon: Icons.play_arrow_rounded,
                                  variant: HumsButtonVariant.primary,
                                  height: 38,
                                  onPressed: () => _playQueue(state.tracks, 0),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
                          HumsButton(
                            label: 'Retry',
                            variant: HumsButtonVariant.primary,
                            onPressed: () {
                              ref.read(likedTracksNotifierProvider.notifier).refresh();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ] else if (state.tracks.isEmpty) ...[
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: HumsEmptyState(
                    icon: Icons.favorite_border_rounded,
                    title: 'No liked songs yet.',
                    description: "Tap ❤️ on songs you love and they'll appear here.",
                    actionLabel: 'Discover Music',
                    onAction: () => context.push(RouteNames.searchPath),
                  ),
                ),
              ] else ...[
                // Track list using HumsTrackTile
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final track = state.tracks[index];
                      final isCurrent = currentPlayingTrackId == track.id;

                      return HumsTrackTile(
                        index: index + 1,
                        title: track.title,
                        artistName: track.artistName,
                        formattedDuration: track.formattedDuration,
                        isPlaying: isCurrent,
                        isLiked: true,
                        onTap: () => _playQueue(state.tracks, index),
                        onLikeToggle: () {
                          ref.read(likeNotifierProvider(track.id).notifier).toggleLike();
                        },
                        trailing: DownloadButton(
                          trackId: track.id,
                          title: track.title,
                          artistName: track.artistName,
                          albumName: track.albumName,
                          durationSeconds: track.durationSeconds,
                          size: 20,
                        ),
                        onMoreTap: () => _showTrackMenu(context, track),
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
                        child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
                      ),
                    ),
                  ),
                ],

                const SliverToBoxAdapter(
                  child: SizedBox(height: 100),
                ),
              ],
            ],
          ),

          // Floating MiniPlayer at bottom
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
