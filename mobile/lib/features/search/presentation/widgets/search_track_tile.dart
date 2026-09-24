import 'package:flutter/material.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/core/theme/app_spacing.dart';
import 'package:hums_mobile/core/theme/app_typography.dart';
import 'package:hums_mobile/features/search/domain/entities/search_track_entity.dart';

class SearchTrackTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
      trailing: Text(
        track.formattedDuration,
        style: AppTypography.labelSmall.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      onTap: onTap,
    );
  }
}
