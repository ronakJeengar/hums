import 'package:flutter/material.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/core/theme/app_radii.dart';
import 'package:hums_mobile/core/theme/app_spacing.dart';
import 'package:hums_mobile/core/theme/app_typography.dart';
import 'package:hums_mobile/core/widgets/hums_artwork.dart';

class HumsTrackTile extends StatelessWidget {
  final String title;
  final String? artistName;
  final String? imageUrl;
  final String? formattedDuration;
  final bool isPlaying;
  final bool isLiked;
  final VoidCallback? onTap;
  final VoidCallback? onLikeToggle;
  final VoidCallback? onMoreTap;
  final Widget? trailing;
  final int? index;

  const HumsTrackTile({
    super.key,
    required this.title,
    this.artistName,
    this.imageUrl,
    this.formattedDuration,
    this.isPlaying = false,
    this.isLiked = false,
    this.onTap,
    this.onLikeToggle,
    this.onMoreTap,
    this.trailing,
    this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 3.0,
      ),
      decoration: BoxDecoration(
        color: isPlaying
            ? AppColors.primary.withValues(alpha: 0.08)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: isPlaying
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.borderSubtle,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm + 4,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              if (index != null) ...[
                SizedBox(
                  width: 24,
                  child: Text(
                    '$index',
                    textAlign: TextAlign.center,
                    style: AppTypography.labelMedium.copyWith(
                      color: isPlaying ? AppColors.primary : AppColors.textTertiary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              HumsArtwork(
                imageUrl: imageUrl,
                size: 44,
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleMedium.copyWith(
                        color: isPlaying ? AppColors.primary : AppColors.textPrimary,
                        fontWeight: isPlaying ? FontWeight.w700 : FontWeight.w600,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      artistName ?? 'Unknown Artist',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (formattedDuration != null) ...[
                const SizedBox(width: AppSpacing.xs),
                Text(
                  formattedDuration!,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
              if (onLikeToggle != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(
                    isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    size: 20,
                    color: isLiked ? AppColors.primary : AppColors.textTertiary,
                  ),
                  onPressed: onLikeToggle,
                  splashRadius: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
              if (trailing != null) ...[
                const SizedBox(width: 4),
                trailing!,
              ],
              if (onMoreTap != null) ...[
                IconButton(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    size: 20,
                    color: AppColors.textTertiary,
                  ),
                  onPressed: onMoreTap,
                  splashRadius: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
