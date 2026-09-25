import 'package:flutter/material.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/core/theme/app_spacing.dart';
import 'package:hums_mobile/core/theme/app_typography.dart';
import 'package:hums_mobile/features/search/domain/entities/search_album_entity.dart';

class SearchAlbumTile extends StatelessWidget {
  final SearchAlbumEntity album;
  final VoidCallback onTap;

  const SearchAlbumTile({
    super.key,
    required this.album,
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
          image: album.coverImageUrl != null && album.coverImageUrl!.isNotEmpty
              ? DecorationImage(
                  image: NetworkImage(album.coverImageUrl!),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: album.coverImageUrl == null || album.coverImageUrl!.isEmpty
            ? const Icon(
                Icons.album_rounded,
                color: AppColors.primary,
                size: 24,
              )
            : null,
      ),
      title: Text(
        album.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.titleMedium.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        album.artistName != null && album.artistName!.isNotEmpty
            ? '${album.artistName} • ${album.trackCount} ${album.trackCount == 1 ? "song" : "songs"}'
            : '${album.trackCount} ${album.trackCount == 1 ? "song" : "songs"}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.labelSmall.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppColors.textTertiary,
        size: 20,
      ),
      onTap: onTap,
    );
  }
}
