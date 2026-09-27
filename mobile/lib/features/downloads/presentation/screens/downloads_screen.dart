import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/core/theme/app_spacing.dart';
import 'package:hums_mobile/core/theme/app_typography.dart';
import 'package:hums_mobile/features/audio_player/presentation/providers/audio_player_provider.dart';
import 'package:hums_mobile/features/downloads/presentation/providers/download_manager_provider.dart';
import 'package:hums_mobile/features/downloads/presentation/widgets/download_item_tile.dart';
import 'package:hums_mobile/features/downloads/presentation/widgets/storage_usage_indicator.dart';

/// Screen presenting the user's offline downloads library, active queue,
/// and device storage statistics.
class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key});

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _playAllOffline(List<String> trackIds) {
    if (trackIds.isEmpty) return;
    // Play the first track; the audio player seamlessly loads from local disk
    ref.read(audioPlayerNotifierProvider.notifier).playTrack(trackIds.first);
  }

  @override
  Widget build(BuildContext context) {
    final downloadState = ref.watch(downloadManagerProvider);
    final completed = downloadState.completedDownloads;
    final active = downloadState.activeDownloads;
    final failed = downloadState.failedDownloads;
    final inProgressCount = active.length + failed.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'Downloads & Offline',
          style: AppTypography.headlineLarge.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w600),
          tabs: [
            Tab(text: 'Downloaded (${completed.length})'),
            Tab(
              text: inProgressCount > 0
                  ? 'Active ($inProgressCount)'
                  : 'Active',
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          const StorageUsageIndicator(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Completed Downloads
                completed.isEmpty
                    ? _buildEmptyState(
                        icon: Icons.cloud_download_outlined,
                        title: 'No Offline Music Yet',
                        subtitle:
                            'Download your favorite songs and playlists to listen anywhere, even without Wi-Fi or cellular service.',
                      )
                    : Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.xs,
                            ),
                            child: Row(
                              children: [
                                Text(
                                  '${completed.length} songs available offline',
                                  style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const Spacer(),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.md,
                                      vertical: AppSpacing.xs,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(AppSpacing.radiusFull),
                                    ),
                                  ),
                                  icon: const Icon(Icons.play_arrow, size: 18),
                                  label: const Text('Play All'),
                                  onPressed: () => _playAllOffline(
                                    completed.map((e) => e.trackId).toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(color: AppColors.divider, height: 1),
                          Expanded(
                            child: ListView.builder(
                              itemCount: completed.length,
                              itemBuilder: (context, index) {
                                return DownloadItemTile(item: completed[index]);
                              },
                            ),
                          ),
                        ],
                      ),

                // Tab 2: Active / In-progress Queue
                active.isEmpty && failed.isEmpty
                    ? _buildEmptyState(
                        icon: Icons.check_circle_outline,
                        title: 'All Caught Up',
                        subtitle: 'No active or pending downloads in the queue.',
                      )
                    : ListView(
                        children: [
                          if (failed.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.md,
                                AppSpacing.md,
                                AppSpacing.md,
                                AppSpacing.xs,
                              ),
                              child: Text(
                                'Failed Downloads (${failed.length})',
                                style: AppTypography.labelLarge.copyWith(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            ...failed.map((item) => DownloadItemTile(item: item)),
                          ],
                          if (active.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.md,
                                AppSpacing.md,
                                AppSpacing.md,
                                AppSpacing.xs,
                              ),
                              child: Text(
                                'Downloading & Queued (${active.length})',
                                style: AppTypography.labelLarge.copyWith(
                                  color: AppColors.primaryLight,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            ...active.map((item) => DownloadItemTile(item: item)),
                          ],
                        ],
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(
                icon,
                size: 36,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              subtitle,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
