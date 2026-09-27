import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/core/theme/app_spacing.dart';
import 'package:hums_mobile/core/theme/app_typography.dart';
import 'package:hums_mobile/features/audio_player/presentation/widgets/mini_player.dart';
import 'package:hums_mobile/features/library/presentation/providers/library_provider.dart';
import 'package:hums_mobile/routing/route_names.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSummary = ref.watch(librarySummaryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          'My Library',
          style: AppTypography.headlineMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: AppColors.textPrimary),
            onPressed: () => context.push(RouteNames.searchPath),
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              ref.invalidate(librarySummaryProvider);
              await ref.read(librarySummaryProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              children: [
                // 1. Liked Songs Hero Card
                asyncSummary.when(
                  data: (summary) => _buildLikedSongsCard(
                    context,
                    summary.likedTracksCount,
                  ),
                  loading: () => _buildLikedSongsCard(context, 0, isLoading: true),
                  error: (e, _) => _buildLikedSongsCard(context, 0),
                ),

                const SizedBox(height: AppSpacing.lg),

                // 2. Library Navigation Sections
                Text(
                  'Collections & Activity',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                _buildNavigationTile(
                  context: context,
                  icon: Icons.history_rounded,
                  iconColor: AppColors.primaryLight,
                  title: 'Recently Played',
                  subtitle: 'Review your listening history',
                  route: RouteNames.historyPath,
                ),
                _buildNavigationTile(
                  context: context,
                  icon: Icons.download_for_offline_outlined,
                  iconColor: AppColors.success,
                  title: 'Downloaded',
                  subtitle: 'Offline tracks & episodes',
                  route: RouteNames.downloadsPath,
                ),
                _buildNavigationTile(
                  context: context,
                  icon: Icons.playlist_play_rounded,
                  iconColor: AppColors.primary,
                  title: 'Playlists',
                  subtitle: asyncSummary.maybeWhen(
                    data: (s) => '${s.playlistsCount} collections',
                    orElse: () => 'Organize your music',
                  ),
                  route: RouteNames.playlistsPath,
                ),
                _buildNavigationTile(
                  context: context,
                  icon: Icons.people_outline_rounded,
                  iconColor: AppColors.info,
                  title: 'Following',
                  subtitle: asyncSummary.maybeWhen(
                    data: (s) => '${s.followingCreatorsCount} artists',
                    orElse: () => 'Artists you follow',
                  ),
                  route: RouteNames.followingPath,
                ),
                _buildNavigationTile(
                  context: context,
                  icon: Icons.cloud_upload_outlined,
                  iconColor: AppColors.textSecondary,
                  title: 'My Tracks',
                  subtitle: 'Your uploaded audio & episodes',
                  route: RouteNames.userTracksPath,
                ),

                const SizedBox(height: 100), // Bottom space for MiniPlayer
              ],
            ),
          ),

          // Floating MiniPlayer
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

  Widget _buildLikedSongsCard(
    BuildContext context,
    int likedCount, {
    bool isLoading = false,
  }) {
    return InkWell(
      onTap: () => context.push(RouteNames.likedSongsPath),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE5484D), Color(0xFF8E1F24)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          boxShadow: [
            BoxShadow(
              color: AppColors.error.withValues(alpha: 0.25),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.favorite_rounded,
                  color: Colors.white,
                  size: 30,
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
                    style: AppTypography.headlineMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    isLoading
                        ? 'Loading songs...'
                        : '$likedCount ${likedCount == 1 ? "song" : "songs"}',
                    style: AppTypography.bodyMedium.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white70,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String route,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xxs,
        ),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          color: AppColors.textTertiary,
          size: 14,
        ),
        onTap: () => context.push(route),
      ),
    );
  }
}
