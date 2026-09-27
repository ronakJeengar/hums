import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/core/theme/app_radii.dart';
import 'package:hums_mobile/features/audio_player/presentation/providers/audio_player_provider.dart';
import 'package:hums_mobile/routing/route_names.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasTrack = ref.watch(
      audioPlayerNotifierProvider.select((s) => s.hasTrack),
    );

    if (!hasTrack) {
      return const SizedBox.shrink();
    }

    final track = ref.watch(
      audioPlayerNotifierProvider.select((s) => s.track!),
    );
    final isPlaying = ref.watch(
      audioPlayerNotifierProvider.select((s) => s.isPlaying),
    );
    final isBuffering = ref.watch(
      audioPlayerNotifierProvider.select((s) => s.isLoading || s.isBuffering),
    );
    final hasNext = ref.watch(
      audioPlayerNotifierProvider.select((s) => s.hasNext),
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.borderSubtle, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            InkWell(
              onTap: () {
                context.pushNamed(RouteNames.player);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    // Track Artwork Thumbnail
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHighlight,
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.music_note_rounded,
                        size: 22,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Title & Artist
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            track.title,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            track.artistName ?? 'Unknown Artist',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Buffering or Play / Pause
                    if (isBuffering)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.primary,
                            ),
                          ),
                        ),
                      )
                    else
                      IconButton(
                        icon: Icon(
                          isPlaying
                              ? Icons.pause_circle_filled_rounded
                              : Icons.play_circle_fill_rounded,
                          size: 36,
                          color: AppColors.primary,
                        ),
                        onPressed: () {
                          ref
                              .read(audioPlayerNotifierProvider.notifier)
                              .togglePlayPause();
                        },
                        splashRadius: 22,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),

                    // Next Track
                    if (hasNext)
                      IconButton(
                        icon: const Icon(
                          Icons.skip_next_rounded,
                          size: 24,
                          color: AppColors.textPrimary,
                        ),
                        onPressed: () {
                          ref
                              .read(audioPlayerNotifierProvider.notifier)
                              .skipToNext();
                        },
                        splashRadius: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),

                    // Close / Stop
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppColors.textTertiary,
                      ),
                      onPressed: () {
                        ref.read(audioPlayerNotifierProvider.notifier).stop();
                      },
                      splashRadius: 18,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                  ],
                ),
              ),
            ),
            // Progress Bar
            const _MiniPlayerProgressBar(),
          ],
        ),
      ),
    ),
  );
}
}

class _MiniPlayerProgressBar extends ConsumerWidget {
  const _MiniPlayerProgressBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(
      audioPlayerNotifierProvider.select((s) => s.progress),
    );

    return LinearProgressIndicator(
      value: progress,
      backgroundColor: AppColors.surfaceHighlight.withValues(alpha: 0.5),
      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
      minHeight: 2.0,
    );
  }
}
