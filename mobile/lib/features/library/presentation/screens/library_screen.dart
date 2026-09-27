import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/core/theme/app_radii.dart';
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
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'My Library',
          style: AppTypography.headlineLarge,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: AppColors.textPrimary),
            onPressed: () => context.push(RouteNames.searchPath),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: () async {
          ref.invalidate(librarySummaryProvider);
          await ref.read(librarySummaryProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
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

            const SizedBox(height: AppSpacing.xl),

            // 2. Library Navigation Sections
            const Text(
              'Collections & Activity',
              style: AppTypography.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),

            _buildNavigationTile(
              context: context,
              icon: Icons.history_rounded,
              iconColor: AppColors.accentPurple,
              title: 'Recently Played',
              subtitle: 'Review your listening history',
              route: RouteNames.historyPath,
            ),
            _buildNavigationTile(
              context: context,
              icon: Icons.download_done_rounded,
              iconColor: AppColors.accentBlue,
              title: 'Downloaded',
              subtitle: 'Offline tracks & episodes',
              route: RouteNames.downloadsPath,
            ),
            _buildNavigationTile(
              context: context,
              icon: Icons.queue_music_rounded,
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
              iconColor: AppColors.accentMint,
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

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }

  Widget _buildLikedSongsCard(
    BuildContext context,
    int likedCount, {
    bool isLoading = false,
  }) {
    return InkWell(
      onTap: () => context.push(RouteNames.likedSongsPath),
      borderRadius: BorderRadius.circular(AppRadii.xl),
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
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.favorite_rounded,
                  color: Colors.white,
                  size: 28,
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
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isLoading
                        ? 'Loading songs...'
                        : '$likedCount ${likedCount == 1 ? "song" : "songs"}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white70,
              size: 24,
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
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.borderSubtle, width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xxs,
        ),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          style: AppTypography.titleMedium.copyWith(
            fontSize: 14.5,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: AppTypography.bodyMedium.copyWith(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: AppColors.textTertiary,
          size: 20,
        ),
        onTap: () => context.push(route),
      ),
    );
  }
}
