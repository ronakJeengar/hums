import 'package:flutter/material.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/core/theme/app_spacing.dart';
import 'package:hums_mobile/core/theme/app_typography.dart';
import 'package:hums_mobile/features/search/domain/entities/search_artist_entity.dart';
import 'package:hums_mobile/features/social/presentation/widgets/follow_button.dart';

class SearchArtistTile extends StatelessWidget {
  final SearchArtistEntity artist;
  final VoidCallback onTap;

  const SearchArtistTile({
    super.key,
    required this.artist,
    required this.onTap,
  });

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'A';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      final val = (count / 1000000).toStringAsFixed(1);
      return '${val.endsWith(".0") ? val.substring(0, val.length - 2) : val}M';
    }
    if (count >= 1000) {
      final val = (count / 1000).toStringAsFixed(1);
      return '${val.endsWith(".0") ? val.substring(0, val.length - 2) : val}k';
    }
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    final hasFollow = artist.isFollowing != null;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: AppColors.surfaceElevated,
        backgroundImage: artist.avatarUrl != null && artist.avatarUrl!.isNotEmpty
            ? NetworkImage(artist.avatarUrl!)
            : null,
        child: artist.avatarUrl == null || artist.avatarUrl!.isEmpty
            ? Text(
                _getInitials(artist.name),
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              artist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (artist.isVerified) ...[
            const SizedBox(width: AppSpacing.xxs),
            const Icon(
              Icons.verified_rounded,
              color: AppColors.primary,
              size: 16,
            ),
          ],
        ],
      ),
      subtitle: Text(
        artist.followersCount > 0
            ? '${_formatCount(artist.followersCount)} followers • ${artist.trackCount} ${artist.trackCount == 1 ? "track" : "tracks"}'
            : (artist.trackCount > 0
                ? '${artist.trackCount} ${artist.trackCount == 1 ? "track" : "tracks"}'
                : (artist.bio ?? 'Artist')),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.labelSmall.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasFollow) ...[
            FollowButton(
              creatorId: artist.id,
              initialFollowing: artist.isFollowing ?? false,
              initialCount: artist.followersCount,
              compact: true,
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textSecondary,
            size: 20,
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
