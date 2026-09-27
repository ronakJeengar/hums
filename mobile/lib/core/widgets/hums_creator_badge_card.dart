import 'package:flutter/material.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/core/theme/app_radii.dart';
import 'package:hums_mobile/core/theme/app_spacing.dart';
import 'package:hums_mobile/core/theme/app_typography.dart';
import 'package:hums_mobile/core/widgets/hums_artwork.dart';

class HumsCreatorBadgeCard extends StatelessWidget {
  final String title;
  final String creatorName;
  final String? artworkUrl;
  final String? creatorAvatarUrl;
  final String? categoryTag;
  final VoidCallback onTap;
  final VoidCallback? onPlayTap;
  final double cardWidth;

  const HumsCreatorBadgeCard({
    super.key,
    required this.title,
    required this.creatorName,
    this.artworkUrl,
    this.creatorAvatarUrl,
    this.categoryTag,
    required this.onTap,
    this.onPlayTap,
    this.cardWidth = 148.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: cardWidth,
      margin: const EdgeInsets.only(right: AppSpacing.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Artwork with Overlapping Creator Avatar Badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                HumsArtwork(
                  imageUrl: artworkUrl,
                  width: cardWidth,
                  height: cardWidth,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  hasShadow: true,
                ),
                // Overlapping circular creator avatar badge at top-left
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.background, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: creatorAvatarUrl != null && creatorAvatarUrl!.isNotEmpty
                          ? Image.network(
                              creatorAvatarUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => _fallbackAvatar(),
                            )
                          : _fallbackAvatar(),
                    ),
                  ),
                ),
                // Optional quick play button at bottom-right
                if (onPlayTap != null)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: onPlayTap,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.5),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            // Category / Genre Tag (e.g. ACOUSTIC, INDIE)
            if (categoryTag != null && categoryTag!.isNotEmpty) ...[
              Text(
                categoryTag!.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.categoryTag.copyWith(
                  color: AppColors.accentCoral,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 2),
            ],
            // Track Title
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.titleMedium.copyWith(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            // Creator Name
            Text(
              creatorName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyMedium.copyWith(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackAvatar() {
    return Container(
      color: AppColors.surfaceElevated,
      child: Center(
        child: Text(
          creatorName.isNotEmpty ? creatorName[0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
