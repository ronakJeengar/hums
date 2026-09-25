import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/core/theme/app_icons.dart';
import 'package:hums_mobile/core/widgets/app_icon.dart';
import 'package:hums_mobile/features/audio_player/presentation/providers/audio_player_provider.dart';
import 'package:hums_mobile/features/downloads/presentation/widgets/download_button.dart';

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
            icon: const AppIcon(
              icon: AppIcons.close,
              size: 24,
              color: AppColors.textPrimary,
            ),
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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxHeight < 720;
            final artworkSize = isCompact ? 160.0 : 260.0;

            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    child: Column(
                      children: [
                        // Top Bar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const AppIcon(
                                icon: AppIcons.close,
                                size: 22,
                                color: AppColors.textPrimary,
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                              splashRadius: 24,
                            ),
                            const Text(
                              'NOW PLAYING',
                              style: TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                              ),
                            ),
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
                        const Spacer(flex: 1),

                        // Artwork / Vinyl Card
                        Center(
                          child: Container(
                            width: artworkSize,
                            height: artworkSize,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.15),
                                  blurRadius: 32,
                                  spreadRadius: 4,
                                ),
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Circular vinyl groove illusion
                                Container(
                                  width: artworkSize * 0.77,
                                  height: artworkSize * 0.77,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.surfaceHighlight,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: artworkSize * 0.54,
                                  height: artworkSize * 0.54,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.surfaceHighlight,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                // Center Icon
                                AppIcon(
                                  icon: AppIcons.waveform,
                                  size: isCompact ? 38 : 56,
                                  color: AppColors.primaryLight,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(flex: 1),

              // Track Metadata
              Column(
                children: [
                  Text(
                    track.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    track.artistName ?? 'Unknown Artist',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (track.albumName != null || track.genre != null) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        if (track.albumName != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceHighlight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              track.albumName!,
                              style: const TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        if (track.genre != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              track.genre!,
                              style: const TextStyle(
                                color: AppColors.primaryLight,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
              const Spacer(flex: 1),

              // Error State Banner
              if (playerState.isError && playerState.error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const AppIcon(
                        icon: AppIcons.error,
                        size: 20,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          playerState.error!.message,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          ref
                              .read(audioPlayerNotifierProvider.notifier)
                              .retry();
                        },
                        child: const Text(
                          'Try Again',
                          style: TextStyle(
                            color: AppColors.primaryLight,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Waveform visualization (if samples exist)
              if (track.waveformSamples.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _WaveformWidget(
                    samples: track.waveformSamples,
                    progress: playerState.progress,
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // Scrubber Slider
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 14),
                  activeTrackColor: AppColors.primary,
                  inactiveTrackColor: AppColors.surfaceHighlight,
                  thumbColor: AppColors.primaryLight,
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
                padding: const EdgeInsets.symmetric(horizontal: 16),
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
                        fontFamily: 'monospace',
                      ),
                    ),
                    Text(
                      _formatDuration(totalDuration),
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 1),

              // Playback Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Previous Track
                  IconButton(
                    icon: AppIcon(
                      icon: AppIcons.previous,
                      size: 26,
                      color: playerState.hasPrevious
                          ? AppColors.textPrimary
                          : AppColors.textTertiary.withValues(alpha: 0.3),
                    ),
                    onPressed: playerState.hasPrevious
                        ? () {
                            ref
                                .read(audioPlayerNotifierProvider.notifier)
                                .skipToPrevious();
                          }
                        : null,
                    splashRadius: 24,
                  ),
                  const SizedBox(width: 12),

                  // Seek Backward 10s
                  IconButton(
                    icon: const AppIcon(
                      icon: AppIcons.seekBackward10,
                      size: 28,
                      color: AppColors.textPrimary,
                    ),
                    onPressed: () {
                      ref
                          .read(audioPlayerNotifierProvider.notifier)
                          .seekBackward10();
                    },
                    splashRadius: 24,
                  ),
                  const SizedBox(width: 16),

                  // Play / Pause / Buffering Button
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AppColors.primaryLight, AppColors.primary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
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
                          ref
                              .read(audioPlayerNotifierProvider.notifier)
                              .togglePlayPause();
                        },
                        child: Center(
                          child: playerState.isLoading ||
                                  playerState.isBuffering
                              ? const SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.background,
                                    ),
                                  ),
                                )
                              : AppIcon(
                                  icon: playerState.isPlaying
                                      ? AppIcons.pause
                                      : AppIcons.play,
                                  size: 34,
                                  color: AppColors.background,
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Seek Forward 30s
                  IconButton(
                    icon: const AppIcon(
                      icon: AppIcons.seekForward30,
                      size: 28,
                      color: AppColors.textPrimary,
                    ),
                    onPressed: () {
                      ref
                          .read(audioPlayerNotifierProvider.notifier)
                          .seekForward30();
                    },
                    splashRadius: 24,
                  ),
                  const SizedBox(width: 12),

                  // Next Track
                  IconButton(
                    icon: AppIcon(
                      icon: AppIcons.next,
                      size: 26,
                      color: playerState.hasNext
                          ? AppColors.textPrimary
                          : AppColors.textTertiary.withValues(alpha: 0.3),
                    ),
                    onPressed: playerState.hasNext
                        ? () {
                            ref
                                .read(audioPlayerNotifierProvider.notifier)
                                .skipToNext();
                          }
                        : null,
                    splashRadius: 24,
                  ),
                ],
              ),
              const Spacer(flex: 1),

              // Audio Quality Indicator
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  '${track.audio.format.toUpperCase()} · ${track.audio.bitrateKbps} kbps',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    ),
  );
},
),
),
);
  }
}

class _WaveformWidget extends StatelessWidget {
  final List<double> samples;
  final double progress;

  const _WaveformWidget({
    required this.samples,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final barCount = samples.length.clamp(1, 100);
          final barWidth = (constraints.maxWidth / barCount) - 1.5;

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(barCount, (index) {
              final sample = samples[index].clamp(0.05, 1.0);
              final barProgress = index / barCount;
              final isPlayed = barProgress <= progress;

              return Container(
                width: barWidth > 1.0 ? barWidth : 1.0,
                height: 36 * sample,
                decoration: BoxDecoration(
                  color:
                      isPlayed ? AppColors.primary : AppColors.surfaceHighlight,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
