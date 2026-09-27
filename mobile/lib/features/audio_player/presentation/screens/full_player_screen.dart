import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/core/theme/app_icons.dart';
import 'package:hums_mobile/core/theme/app_radii.dart';
import 'package:hums_mobile/core/theme/app_spacing.dart';
import 'package:hums_mobile/core/theme/app_typography.dart';
import 'package:hums_mobile/core/widgets/app_icon.dart';
import 'package:hums_mobile/core/widgets/hums_bottom_sheet.dart';
import 'package:hums_mobile/features/audio_player/presentation/providers/audio_player_provider.dart';
import 'package:hums_mobile/features/downloads/presentation/widgets/download_button.dart';
import 'package:hums_mobile/features/library/presentation/widgets/like_button.dart';

class FullPlayerScreen extends ConsumerStatefulWidget {
  const FullPlayerScreen({super.key});

  @override
  ConsumerState<FullPlayerScreen> createState() => _FullPlayerScreenState();
}

class _FullPlayerScreenState extends ConsumerState<FullPlayerScreen> {
  double? _dragValue;

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours;
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  void _showQueueSheet(BuildContext context) {
    final playerState = ref.read(audioPlayerNotifierProvider);
    final queue = playerState.queue;

    HumsBottomSheet.show(
      context: context,
      title: 'Playing Queue',
      child: queue == null || queue.items.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(
                child: Text(
                  'No tracks currently queued.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          : ListView.builder(
              shrinkWrap: true,
              itemCount: queue.items.length,
              itemBuilder: (context, index) {
                final item = queue.items[index];
                final isCurrent = index == queue.currentIndex;

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : AppColors.surfaceHighlight,
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        color: isCurrent ? AppColors.primary : AppColors.textTertiary,
                      ),
                    ),
                  ),
                  title: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isCurrent ? AppColors.primary : AppColors.textPrimary,
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    item.artistName ?? 'Unknown Artist',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  trailing: isCurrent
                      ? const Icon(Icons.equalizer_rounded, color: AppColors.primary, size: 20)
                      : null,
                  onTap: () {
                    Navigator.of(context).pop();
                    if (!isCurrent) {
                      ref.read(audioPlayerNotifierProvider.notifier).playTrack(item.trackId);
                    }
                  },
                );
              },
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(audioPlayerNotifierProvider);

    if (!playerState.hasTrack) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28, color: AppColors.textPrimary),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(
          child: Text(
            'No track currently playing',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
          ),
        ),
      );
    }

    final track = playerState.track!;
    final totalDuration = playerState.duration;
    final currentPosition = playerState.position;

    final currentMs = _dragValue ?? currentPosition.inMilliseconds.toDouble();
    final totalMs = totalDuration.inMilliseconds.toDouble();
    final maxMs = totalMs > 0 ? totalMs : 1.0;
    final sliderValue = currentMs.clamp(0.0, maxMs);

    final nextTrack = playerState.hasNext &&
            playerState.queue != null &&
            playerState.queue!.nextIndex != null
        ? playerState.queue!.items[playerState.queue!.nextIndex!]
        : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Ambient Radial Gradient Aura in background
          Positioned(
            top: -60,
            left: -40,
            right: -40,
            height: 380,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.18),
                    AppColors.background.withValues(alpha: 0.0),
                  ],
                  radius: 0.8,
                ),
              ),
            ),
          ),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxHeight < 700;
                final artworkSize = isCompact ? 180.0 : 250.0;

                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        child: Column(
                          children: [
                            // Top Bar
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 30,
                                    color: AppColors.textPrimary,
                                  ),
                                  onPressed: () => Navigator.of(context).pop(),
                                  splashRadius: 24,
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceElevated,
                                    borderRadius: BorderRadius.circular(AppRadii.pill),
                                    border: Border.all(color: AppColors.borderSubtle),
                                  ),
                                  child: const Text(
                                    'NOW PLAYING',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.more_horiz_rounded,
                                    size: 24,
                                    color: AppColors.textPrimary,
                                  ),
                                  onPressed: () => _showQueueSheet(context),
                                  splashRadius: 24,
                                ),
                              ],
                            ),

                            // Error State Banner
                            if (playerState.isError && playerState.error != null)
                              Container(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        playerState.error!.message,
                                        style: const TextStyle(color: AppColors.error, fontSize: 12),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => ref.read(audioPlayerNotifierProvider.notifier).retry(),
                                      child: const Text(
                                        'Try Again',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            const Spacer(flex: 1),

                            // Artwork Card with drop shadow and border
                            Center(
                              child: Container(
                                width: artworkSize,
                                height: artworkSize,
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(AppRadii.xxl),
                                  border: Border.all(
                                    color: AppColors.borderSubtle,
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.55),
                                      blurRadius: 28,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: artworkSize * 0.78,
                                      height: artworkSize * 0.78,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppColors.surfaceHighlight.withValues(alpha: 0.4),
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: artworkSize * 0.52,
                                      height: artworkSize * 0.52,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppColors.surfaceHighlight.withValues(alpha: 0.3),
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.graphic_eq_rounded,
                                      size: 52,
                                      color: AppColors.primary,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const Spacer(flex: 1),

                            // Track Metadata & Action Row
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        track.title,
                                        style: AppTypography.headlineLarge.copyWith(fontSize: 22),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        track.artistName ?? 'Unknown Artist',
                                        style: AppTypography.bodyMedium.copyWith(fontSize: 14),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                LikeButton(
                                  trackId: track.trackId,
                                  size: 26,
                                ),
                                const SizedBox(width: 8),
                                DownloadButton(
                                  trackId: track.trackId,
                                  title: track.title,
                                  artistName: track.artistName,
                                  albumName: track.albumName,
                                  durationSeconds: track.durationSeconds,
                                  size: 24,
                                  color: AppColors.textPrimary,
                                ),
                              ],
                            ),

                            // Album and Genre badges
                            if (track.albumName != null || track.genre != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  if (track.albumName != null) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceElevated,
                                        borderRadius: BorderRadius.circular(AppRadii.sm),
                                      ),
                                      child: Text(
                                        track.albumName!,
                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  if (track.genre != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(AppRadii.sm),
                                      ),
                                      child: Text(
                                        track.genre!,
                                        style: const TextStyle(fontSize: 11, color: AppColors.primary),
                                      ),
                                    ),
                                ],
                              ),
                            ],

                            const SizedBox(height: AppSpacing.md),

                            // Scrubber Slider
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 4,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                activeTrackColor: AppColors.primary,
                                inactiveTrackColor: AppColors.surfaceHighlight,
                                thumbColor: AppColors.whitePill,
                                overlayColor: AppColors.primary.withValues(alpha: 0.2),
                              ),
                              child: Slider(
                                value: sliderValue,
                                min: 0.0,
                                max: maxMs,
                                onChanged: (value) {
                                  setState(() {
                                    _dragValue = value;
                                  });
                                },
                                onChangeEnd: (value) {
                                  ref
                                      .read(audioPlayerNotifierProvider.notifier)
                                      .seek(Duration(milliseconds: value.toInt()));
                                  setState(() {
                                    _dragValue = null;
                                  });
                                },
                              ),
                            ),

                            // Timestamps
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(
                                      _dragValue != null
                                          ? Duration(milliseconds: _dragValue!.toInt())
                                          : currentPosition,
                                    ),
                                    style: const TextStyle(
                                      color: AppColors.textTertiary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    _formatDuration(totalDuration),
                                    style: const TextStyle(
                                      color: AppColors.textTertiary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const Spacer(flex: 1),

                            // Playback Controls Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  icon: const AppIcon(
                                    icon: AppIcons.seekBackward10,
                                    size: 26,
                                    color: AppColors.textSecondary,
                                  ),
                                  onPressed: () {
                                    ref.read(audioPlayerNotifierProvider.notifier).seekBackward10();
                                  },
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.skip_previous_rounded,
                                    size: 34,
                                    color: playerState.hasPrevious
                                        ? AppColors.textPrimary
                                        : AppColors.textTertiary.withValues(alpha: 0.3),
                                  ),
                                  onPressed: playerState.hasPrevious
                                      ? () {
                                          ref.read(audioPlayerNotifierProvider.notifier).skipToPrevious();
                                        }
                                      : null,
                                ),
                                // Main Play / Pause Button (68px circle)
                                Container(
                                  width: 68,
                                  height: 68,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.primary,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(alpha: 0.4),
                                        blurRadius: 18,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: () {
                                        ref.read(audioPlayerNotifierProvider.notifier).togglePlayPause();
                                      },
                                      child: Center(
                                        child: playerState.isLoading || playerState.isBuffering
                                            ? const SizedBox(
                                                width: 26,
                                                height: 26,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2.5,
                                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                ),
                                              )
                                            : Icon(
                                                playerState.isPlaying
                                                    ? Icons.pause_rounded
                                                    : Icons.play_arrow_rounded,
                                                size: 38,
                                                color: Colors.white,
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.skip_next_rounded,
                                    size: 34,
                                    color: playerState.hasNext
                                        ? AppColors.textPrimary
                                        : AppColors.textTertiary.withValues(alpha: 0.3),
                                  ),
                                  onPressed: playerState.hasNext
                                      ? () {
                                          ref.read(audioPlayerNotifierProvider.notifier).skipToNext();
                                        }
                                      : null,
                                ),
                                IconButton(
                                  icon: const AppIcon(
                                    icon: AppIcons.seekForward30,
                                    size: 26,
                                    color: AppColors.textSecondary,
                                  ),
                                  onPressed: () {
                                    ref.read(audioPlayerNotifierProvider.notifier).seekForward30();
                                  },
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // Audio Quality Indicator
                            Text(
                              '${track.audio.format.toUpperCase()} · ${track.audio.bitrateKbps} kbps',
                              style: const TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),

                            const SizedBox(height: 8),

                            // "Up Next" Bottom Pill Drawer (Reference Pattern)
                            InkWell(
                              onTap: () => _showQueueSheet(context),
                              borderRadius: BorderRadius.circular(AppRadii.pill),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(AppRadii.pill),
                                  border: Border.all(color: AppColors.borderSubtle, width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.queue_music_rounded,
                                      size: 18,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 220),
                                      child: Text(
                                        nextTrack != null
                                            ? 'Up Next: ${nextTrack.title}'
                                            : 'Queue & Up Next',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      size: 18,
                                      color: AppColors.textTertiary,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
