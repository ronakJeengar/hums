import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/core/theme/app_spacing.dart';
import 'package:hums_mobile/core/theme/app_typography.dart';
import 'package:hums_mobile/features/audio/domain/entities/track_entity.dart';
import 'package:hums_mobile/features/audio_player/domain/entities/player_queue.dart';
import 'package:hums_mobile/features/audio_player/presentation/providers/audio_player_provider.dart';
import 'package:hums_mobile/features/audio_player/presentation/widgets/mini_player.dart';
import 'package:hums_mobile/features/social/presentation/providers/creator_profile_provider.dart';
import 'package:hums_mobile/features/social/presentation/providers/follow_notifier.dart';
import 'package:hums_mobile/features/social/presentation/widgets/follow_button.dart';
import 'package:hums_mobile/features/library/presentation/widgets/like_button.dart';
import 'package:hums_mobile/routing/route_names.dart';

class CreatorProfileScreen extends ConsumerWidget {
  final String creatorId;

  const CreatorProfileScreen({
    super.key,
    required this.creatorId,
  });

  String _formatCount(int count) {
    if (count >= 1000000) {
      final val = (count / 1000000).toStringAsFixed(1);
      return '${val.endsWith(".0") ? val.substring(0, val.length - 2) : val}M';
    }
    if (count >= 1000) {
      final val = (count / 1000).toStringAsFixed(1);
      return '${val.endsWith(".0") ? val.substring(0, val.length - 2) : val}k';
    }
    return count.toString();
  }

  String _formatDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return '--:--';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'A';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  void _playTracks(
    WidgetRef ref,
    List<TrackEntity> tracks,
    int initialIndex,
    String creatorName,
  ) {
    if (tracks.isEmpty) return;

    final queueItems = tracks
        .map(
          (t) => QueueItem(
            trackId: t.id,
            title: t.title,
            artistName: t.artistName ?? creatorName,
            durationSeconds: t.durationSeconds,
          ),
        )
        .toList();

    final queue = PlayerQueue(
      playlistId: 'creator_$creatorId',
      playlistName: creatorName,
      items: queueItems,
      currentIndex: initialIndex,
    );

    ref.read(audioPlayerNotifierProvider.notifier).playQueue(
          queue,
          startIndex: initialIndex,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncDetail = ref.watch(creatorProfileProvider(creatorId));
    final followState = ref.watch(followNotifierProvider(creatorId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: asyncDetail.when(
        data: (detail) {
          final countToDisplay = followState.followersCount > 0
              ? followState.followersCount
              : detail.followersCount;

          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // 1. Sliver AppBar with Cover Image
              SliverAppBar(
                expandedHeight: 240,
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
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Cover Image or Gradient
                      if (detail.coverImageUrl != null &&
                          detail.coverImageUrl!.isNotEmpty)
                        Image.network(
                          detail.coverImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _defaultCover(),
                        )
                      else
                        _defaultCover(),

                      // Gradient overlay for smooth contrast
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.3),
                              AppColors.background.withValues(alpha: 0.95),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Creator Identity Header (Avatar, Name, Verified, Bio, Follow)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: Column(
                    children: [
                      Transform.translate(
                        offset: const Offset(0, -40),
                        child: CircleAvatar(
                          radius: 48,
                          backgroundColor: AppColors.surfaceElevated,
                          backgroundImage: detail.avatarUrl != null &&
                                  detail.avatarUrl!.isNotEmpty
                              ? NetworkImage(detail.avatarUrl!)
                              : null,
                          child: detail.avatarUrl == null ||
                                  detail.avatarUrl!.isEmpty
                              ? Text(
                                  _getInitials(detail.name),
                                  style: AppTypography.headlineLarge.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                      ),

                      // Name + Verification Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              detail.name,
                              style: AppTypography.headlineMedium.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (detail.isVerified) ...[
                            const SizedBox(width: AppSpacing.xxs),
                            const Icon(
                              Icons.verified_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ],
                        ],
                      ),

                      // Username
                      if (detail.username != null &&
                          detail.username!.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          '@${detail.username}',
                          style: AppTypography.labelLarge.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],

                      // Follower Count
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${_formatCount(countToDisplay)} ${countToDisplay == 1 ? "follower" : "followers"}',
                        style: AppTypography.labelLarge.copyWith(
                          color: AppColors.textTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      // Bio
                      if (detail.bio != null && detail.bio!.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          detail.bio!,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      // Follow Button
                      const SizedBox(height: AppSpacing.md),
                      FollowButton(
                        creatorId: creatorId,
                        initialFollowing: detail.isFollowing ?? false,
                        initialCount: detail.followersCount,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ),
                ),
              ),

              // 3. Popular Tracks Section
              if (detail.popularTracks.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.xs,
                    ),
                    child: Text(
                      'Popular Tracks',
                      style: AppTypography.headlineMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final track = detail.popularTracks[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.xxs,
                        ),
                        leading: SizedBox(
                          width: 28,
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
                          track.albumName ?? track.genre ?? 'Track',
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
                              size: 20,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              _formatDuration(track.durationSeconds),
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                        onTap: () => _playTracks(
                          ref,
                          detail.popularTracks,
                          index,
                          detail.name,
                        ),
                      );
                    },
                    childCount: detail.popularTracks.length,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
              ],

              // 4. Albums Section (if available)
              if (detail.albums.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.xs,
                    ),
                    child: Text(
                      'Albums',
                      style: AppTypography.headlineMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 160,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      scrollDirection: Axis.horizontal,
                      itemCount: detail.albums.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final album = detail.albums[index];
                        return Container(
                          width: 120,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusMd),
                          ),
                          padding: const EdgeInsets.all(AppSpacing.xs),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 96,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceElevated,
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusSm,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.album_rounded,
                                  color: AppColors.primary,
                                  size: 36,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                album.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.labelLarge.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${album.trackCount} ${album.trackCount == 1 ? "track" : "tracks"}',
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
              ],

              // 5. Playlists Section (if available)
              if (detail.publicPlaylists.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.xs,
                    ),
                    child: Text(
                      'Playlists',
                      style: AppTypography.headlineMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final p = detail.publicPlaylists[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.xxs,
                        ),
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusSm),
                          ),
                          child: const Icon(
                            Icons.queue_music_rounded,
                            color: AppColors.primary,
                            size: 22,
                          ),
                        ),
                        title: Text(
                          p.name,
                          style: AppTypography.titleMedium.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          '${p.trackCount} tracks',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        onTap: () => context.push(
                          RouteNames.playlistDetailPathFor(p.id),
                        ),
                      );
                    },
                    childCount: detail.publicPlaylists.length,
                  ),
                ),
              ],

              // Padding for bottom MiniPlayer
              const SliverToBoxAdapter(child: SizedBox(height: 90)),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.error,
                  size: 48,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Failed to load creator profile',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  err.toString(),
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton(
                  onPressed: () => ref.refresh(creatorProfileProvider(creatorId)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }

  Widget _defaultCover() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2A1B0E),
            Color(0xFF141416),
          ],
        ),
      ),
    );
  }
}
