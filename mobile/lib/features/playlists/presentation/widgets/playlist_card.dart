import 'package:flutter/material.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/core/theme/app_icons.dart';
import 'package:hums_mobile/core/theme/app_spacing.dart';
import 'package:hums_mobile/core/theme/app_typography.dart';
import 'package:hums_mobile/core/widgets/app_icon.dart';
import 'package:hums_mobile/features/playlists/domain/entities/playlist_entity.dart';

class PlaylistCard extends StatelessWidget {
  final PlaylistEntity playlist;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const PlaylistCard({
    super.key,
    required this.playlist,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              // Cover Artwork
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                child: Container(
                  width: 64,
                  height: 64,
                  color: AppColors.surfaceHighlight,
                  child: playlist.coverImageUrl != null
                      ? Image.network(
                          playlist.coverImageUrl!,
                          width: 64,
                          height: 64,
                          cacheWidth: 160,
                          cacheHeight: 160,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildPlaceholder(),
                        )
                      : _buildPlaceholder(),
                ),
              ),
              const SizedBox(width: AppSpacing.md),

              // Playlist Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.name,
                      style: AppTypography.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '${playlist.trackCount} ${playlist.trackCount == 1 ? 'track' : 'tracks'} • ${playlist.formattedDuration}',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    if (playlist.description != null &&
                        playlist.description!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        playlist.description!,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textTertiary,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Actions Menu
              if (onEdit != null || onDelete != null)
                PopupMenuButton<String>(
                  icon: const AppIcon(
                    icon: AppIcons.more,
                    size: AppIconSizes.md,
                    color: AppColors.textSecondary,
                  ),
                  color: AppColors.surfaceElevated,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  onSelected: (value) {
                    if (value == 'edit') onEdit?.call();
                    if (value == 'delete') onDelete?.call();
                  },
                  itemBuilder: (context) => [
                    if (onEdit != null)
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            const AppIcon(
                              icon: AppIcons.edit,
                              size: AppIconSizes.sm,
                              color: AppColors.textPrimary,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'Edit',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (onDelete != null)
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const AppIcon(
                              icon: AppIcons.delete,
                              size: AppIconSizes.sm,
                              color: AppColors.error,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'Delete',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return const Center(
      child: AppIcon(
        icon: AppIcons.playlist,
        size: AppIconSizes.lg,
        color: AppColors.textTertiary,
      ),
    );
  }
}
