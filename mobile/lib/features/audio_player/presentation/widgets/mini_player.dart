import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/core/theme/app_icons.dart';
import 'package:hums_mobile/core/widgets/app_icon.dart';
import 'package:hums_mobile/features/audio_player/presentation/providers/audio_player_provider.dart';
import 'package:hums_mobile/routing/route_names.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(audioPlayerNotifierProvider);

    if (!playerState.hasTrack) {
      return const SizedBox.shrink();
    }

    final track = playerState.track!;

    return GestureDetector(
      onTap: () {
        context.pushNamed(RouteNames.player);
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
          border: const Border(
            top: BorderSide(color: AppColors.border, width: 1),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Linear Progress Indicator
            LinearProgressIndicator(
              value: playerState.progress,
              backgroundColor: AppColors.surfaceHighlight,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 2.5,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Track Thumbnail / Icon
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHighlight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: const AppIcon(
                      icon: AppIcons.musicNote,
                      size: 22,
                      color: AppColors.primaryLight,
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

                  // Buffering / Loading Indicator or Play/Pause Button
                  if (playerState.isLoading || playerState.isBuffering)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      ),
                    )
                  else
                    IconButton(
                      icon: AppIcon(
                        icon: playerState.isPlaying
                            ? AppIcons.pause
                            : AppIcons.play,
                        size: 26,
                        color: AppColors.primaryLight,
                      ),
                      onPressed: () {
                        ref
                            .read(audioPlayerNotifierProvider.notifier)
                            .togglePlayPause();
                      },
                      splashRadius: 22,
                    ),

                  // Next Track Button (if queue has next)
                  if (playerState.hasNext)
                    IconButton(
                      icon: const AppIcon(
                        icon: AppIcons.next,
                        size: 20,
                        color: AppColors.textPrimary,
                      ),
                      onPressed: () {
                        ref
                            .read(audioPlayerNotifierProvider.notifier)
                            .skipToNext();
                      },
                      splashRadius: 20,
                    ),

                  // Stop / Close Button
                  IconButton(
                    icon: const AppIcon(
                      icon: AppIcons.close,
                      size: 18,
                      color: AppColors.textTertiary,
                    ),
                    onPressed: () {
                      ref.read(audioPlayerNotifierProvider.notifier).stop();
                    },
                    splashRadius: 18,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
