import 'package:flutter/material.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/core/theme/app_icons.dart';
import 'package:hums_mobile/core/theme/app_spacing.dart';
import 'package:hums_mobile/core/theme/app_typography.dart';
import 'package:hums_mobile/core/widgets/app_icon.dart';
import 'package:hums_mobile/features/downloads/presentation/widgets/download_button.dart';
import 'package:hums_mobile/features/playlists/domain/entities/playlist_entity.dart';

class PlaylistTrackTile extends StatelessWidget {
  final PlaylistTrackEntity track;
  final int index;
  final bool isCurrentlyPlaying;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  const PlaylistTrackTile({
    super.key,
    required this.track,
    required this.index,
    this.isCurrentlyPlaying = false,
    required this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isPlayable = track.isPlayable;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: isCurrentlyPlaying
            ? AppColors.primary.withValues(alpha: 0.12)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(
          color: isCurrentlyPlaying
              ? AppColors.primary.withValues(alpha: 0.4)
              : AppColors.border,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 0,
        ),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: AppIcon(
                  icon: AppIcons.drag,
                  size: AppIconSizes.md,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            // Index number
            SizedBox(
              width: 24,
              child: Text(
                '${index + 1}',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  color: isCurrentlyPlaying
                      ? AppColors.primary
                      : AppColors.textTertiary,
                  fontWeight: isCurrentlyPlaying ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
        title: Text(
          track.title,
          style: AppTypography.bodyLarge.copyWith(
            color: !isPlayable
                ? AppColors.textTertiary
                : isCurrentlyPlaying
                    ? AppColors.primary
                    : AppColors.textPrimary,
            fontWeight: isCurrentlyPlaying ? FontWeight.w600 : FontWeight.normal,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            if (!isPlayable) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  track.status,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            Expanded(
              child: Text(
                track.artistName ?? track.albumName ?? 'Unknown Artist',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              track.formattedDuration,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textTertiary,
                fontSize: 12,
              ),
            ),
            if (isPlayable) ...[
              const SizedBox(width: AppSpacing.xs),
              DownloadButton(
                trackId: track.trackId,
                title: track.title,
                artistName: track.artistName,
                albumName: track.albumName,
                durationSeconds: track.durationSeconds,
                size: 20,
              ),
            ],
            if (onRemove != null) ...[
              const SizedBox(width: AppSpacing.xs),
              IconButton(
                icon: const AppIcon(
                  icon: AppIcons.remove,
                  size: AppIconSizes.sm,
                  color: AppColors.textTertiary,
                ),
                tooltip: 'Remove from playlist',
                onPressed: onRemove,
              ),
            ],
          ],
        ),
        onTap: isPlayable ? onTap : null,
      ),
    );
  }
}
