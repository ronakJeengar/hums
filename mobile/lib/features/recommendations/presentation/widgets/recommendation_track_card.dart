import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/core/theme/app_spacing.dart';
import 'package:hums_mobile/core/theme/app_typography.dart';
import 'package:hums_mobile/features/audio_player/presentation/providers/audio_player_provider.dart';
import 'package:hums_mobile/features/recommendations/domain/entities/recommendation_track_entity.dart';

class RecommendationTrackCard extends ConsumerWidget {
  final RecommendationTrackEntity track;
  final VoidCallback? onTap;

  const RecommendationTrackCard({
    super.key,
    required this.track,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(audioPlayerNotifierProvider);
    final isCurrentTrack = playerState.track?.trackId == track.id;
    final isPlaying = isCurrentTrack && playerState.isPlaying;

    return Semantics(
      label: 'Recommended track ${track.title} by ${track.artistName ?? "Unknown Artist"}',
      button: true,
      child: GestureDetector(
        onTap: onTap ??
            () {
              ref.read(audioPlayerNotifierProvider.notifier).playTrack(track.id);
            },
        child: Container(
          width: 150,
          margin: const EdgeInsets.only(right: AppSpacing.md),
          decoration: BoxDecoration(
            color: isCurrentTrack
                ? AppColors.primary.withValues(alpha: 0.08)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: isCurrentTrack ? AppColors.primary : AppColors.border,
              width: isCurrentTrack ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Artwork / Vinyl Header Container
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isCurrentTrack
                        ? [
                            AppColors.primary.withValues(alpha: 0.3),
                            AppColors.primary.withValues(alpha: 0.1),
                          ]
                        : [
                            AppColors.surfaceElevated,
                            AppColors.surface,
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppSpacing.radiusMd),
                    topRight: Radius.circular(AppSpacing.radiusMd),
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.music_note_rounded,
                      size: 48,
                      color: isCurrentTrack
                          ? AppColors.primary
                          : AppColors.textTertiary,
                    ),
                    Positioned(
                      bottom: AppSpacing.xs,
                      right: AppSpacing.xs,
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        decoration: BoxDecoration(
                          color: isCurrentTrack
                              ? AppColors.primary
                              : AppColors.background.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 18,
                          color: isCurrentTrack
                              ? AppColors.textPrimary
                              : AppColors.primary,
                        ),
                      ),
                    ),
                    if (track.genre != null && track.genre!.isNotEmpty)
                      Positioned(
                        top: AppSpacing.xs,
                        left: AppSpacing.xs,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.background.withValues(alpha: 0.75),
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusXs),
                          ),
                          child: Text(
                            track.genre!,
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.primary,
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Track Info
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      style: AppTypography.labelLarge.copyWith(
                        color: isCurrentTrack
                            ? AppColors.primary
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      track.artistName ?? 'Unknown Artist',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      track.formattedDuration,
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
