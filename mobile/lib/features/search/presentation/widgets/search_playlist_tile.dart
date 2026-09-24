import 'package:flutter/material.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/core/theme/app_spacing.dart';
import 'package:hums_mobile/core/theme/app_typography.dart';
import 'package:hums_mobile/features/search/domain/entities/search_playlist_entity.dart';

class SearchPlaylistTile extends StatelessWidget {
  final SearchPlaylistEntity playlist;
  final VoidCallback onTap;

  const SearchPlaylistTile({
    super.key,
    required this.playlist,
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
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: Border.all(color: AppColors.border),
          image: playlist.coverImageUrl != null && playlist.coverImageUrl!.isNotEmpty
              ? DecorationImage(
                  image: NetworkImage(playlist.coverImageUrl!),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: playlist.coverImageUrl == null || playlist.coverImageUrl!.isEmpty
            ? const Center(
                child: Icon(
                  Icons.queue_music_rounded,
                  color: AppColors.primary,
                  size: AppSpacing.iconSm,
                ),
              )
            : null,
      ),
      title: Text(
        playlist.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.titleMedium.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Row(
        children: [
          Icon(
            playlist.isPublic ? Icons.public_rounded : Icons.lock_outline_rounded,
            size: 12,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            '${playlist.trackCount} ${playlist.trackCount == 1 ? "track" : "tracks"}',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textSecondary,
        size: 20,
      ),
      onTap: onTap,
    );
  }
}
