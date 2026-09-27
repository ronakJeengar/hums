import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/core/theme/app_spacing.dart';
import 'package:hums_mobile/core/theme/app_typography.dart';
import 'package:hums_mobile/features/audio_player/domain/entities/player_queue.dart';
import 'package:hums_mobile/features/audio_player/presentation/providers/audio_player_provider.dart';
import 'package:hums_mobile/features/library/presentation/widgets/like_button.dart';
import 'package:hums_mobile/features/search/domain/entities/search_track_entity.dart';

class SearchTrackTile extends ConsumerWidget {
  final SearchTrackEntity track;
  final bool isCurrentTrack;
  final bool isPlaying;
  final VoidCallback onTap;

  const SearchTrackTile({
    super.key,
    required this.track,
    this.isCurrentTrack = false,
    this.isPlaying = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isCurrentTrack
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: Border.all(
            color: isCurrentTrack ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Center(
          child: Icon(
            isCurrentTrack && isPlaying
                ? Icons.pause_rounded
                : Icons.music_note_rounded,
            color: isCurrentTrack ? AppColors.primary : AppColors.textSecondary,
            size: AppSpacing.iconSm,
          ),
        ),
      ),
      title: Text(
        track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.titleMedium.copyWith(
          color: isCurrentTrack ? AppColors.primary : AppColors.textPrimary,
          fontWeight: isCurrentTrack ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      subtitle: Text(
        [
          if (track.artistName != null && track.artistName!.isNotEmpty)
            track.artistName,
          if (track.albumName != null && track.albumName!.isNotEmpty)
            track.albumName,
          if (track.genre != null && track.genre!.isNotEmpty) track.genre,
        ].join(' • '),
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
            track.formattedDuration,
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert,
              size: 20,
              color: AppColors.textTertiary,
            ),
            color: AppColors.surfaceElevated,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              side: const BorderSide(color: AppColors.border),
            ),
            onSelected: (value) {
              if (value == 'play_next') {
                final queueItem = QueueItem(
                  trackId: track.id,
                  title: track.title,
                  artistName: track.artistName,
                  albumName: track.albumName,
                  durationSeconds: track.durationSeconds,
                  status: track.status,
                  source: QueueItemSource.search,
                );
                ref.read(audioPlayerNotifierProvider.notifier).playNext(queueItem);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Playing next: ${track.title}'),
                    duration: const Duration(seconds: 2),
                    backgroundColor: AppColors.surfaceElevated,
                  ),
                );
              } else if (value == 'add_to_queue') {
                final queueItem = QueueItem(
                  trackId: track.id,
                  title: track.title,
                  artistName: track.artistName,
                  albumName: track.albumName,
                  durationSeconds: track.durationSeconds,
                  status: track.status,
                  source: QueueItemSource.search,
                );
                ref.read(audioPlayerNotifierProvider.notifier).addToQueue(queueItem);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Added to queue: ${track.title}'),
                    duration: const Duration(seconds: 2),
                    backgroundColor: AppColors.surfaceElevated,
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'play_next',
                child: Row(
                  children: [
                    const Icon(Icons.playlist_play, size: 20, color: AppColors.primaryLight),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Play next', style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'add_to_queue',
                child: Row(
                  children: [
                    const Icon(Icons.queue_music, size: 20, color: AppColors.primaryLight),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Add to queue', style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
