import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/core/theme/app_icons.dart';
import 'package:hums_mobile/core/theme/app_spacing.dart';
import 'package:hums_mobile/core/theme/app_typography.dart';
import 'package:hums_mobile/core/widgets/app_icon.dart';
import 'package:hums_mobile/core/widgets/hums_app_bar.dart';
import 'package:hums_mobile/features/audio_player/presentation/widgets/mini_player.dart';
import 'package:hums_mobile/features/playlists/domain/entities/playlist_entity.dart';
import 'package:hums_mobile/features/playlists/presentation/providers/playlist_provider.dart';
import 'package:hums_mobile/features/playlists/presentation/widgets/playlist_card.dart';

class PlaylistListScreen extends ConsumerStatefulWidget {
  const PlaylistListScreen({super.key});

  @override
  ConsumerState<PlaylistListScreen> createState() => _PlaylistListScreenState();
}

class _PlaylistListScreenState extends ConsumerState<PlaylistListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(playlistListNotifierProvider.notifier).loadPlaylists();
    });
  }

  void _confirmDelete(PlaylistEntity playlist) {
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
        content: Text(
          'Are you sure you want to delete "${playlist.name}"? This action cannot be undone.',
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
                  .deletePlaylist(playlist.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Deleted "${playlist.name}"'
                          : 'Failed to delete playlist',
                    ),
                    backgroundColor:
                        success ? AppColors.surfaceElevated : AppColors.error,
                  ),
                );
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
    final state = ref.watch(playlistListNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: HumsAppBar(
        title: 'Playlists',
        leading: IconButton(
          icon: const AppIcon(
            icon: AppIcons.back,
            size: AppIconSizes.md,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const AppIcon(
              icon: AppIcons.add,
              size: AppIconSizes.md,
              color: AppColors.primary,
            ),
            tooltip: 'New Playlist',
            onPressed: () => context.push('/playlists/create'),
          ),
        ],
      ),
      body: SafeArea(
        child: _buildBody(state),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
        icon: const AppIcon(
          icon: AppIcons.add,
          size: AppIconSizes.md,
          color: Colors.black,
        ),
        label: Text(
          'New Playlist',
          style: AppTypography.labelLarge.copyWith(color: Colors.black),
        ),
        onPressed: () => context.push('/playlists/create'),
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }

  Widget _buildBody(dynamic state) {
    if (state.isLoading && state.playlists.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (state.hasError && state.playlists.isEmpty) {
      return Center(
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
                'Failed to load playlists',
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
                onPressed: () =>
                    ref.read(playlistListNotifierProvider.notifier).loadPlaylists(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppIcon(
                icon: AppIcons.playlist,
                size: AppIconSizes.xxl,
                color: AppColors.textTertiary,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'No playlists yet',
                style: AppTypography.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Create playlists to organize your favorite tracks and queue them for continuous playback.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton.icon(
                onPressed: () => context.push('/playlists/create'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                ),
                icon: const AppIcon(
                  icon: AppIcons.add,
                  size: AppIconSizes.sm,
                  color: Colors.black,
                ),
                label: const Text('Create Playlist'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surfaceElevated,
      onRefresh: () => ref.read(playlistListNotifierProvider.notifier).refresh(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          80, // Padding for FAB / MiniPlayer
        ),
        itemCount: state.playlists.length,
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final playlist = state.playlists[index];
          return PlaylistCard(
            playlist: playlist,
            onTap: () => context.push('/playlists/${playlist.id}'),
            onEdit: () => context.push('/playlists/${playlist.id}/edit'),
            onDelete: () => _confirmDelete(playlist),
          );
        },
      ),
    );
  }
}
