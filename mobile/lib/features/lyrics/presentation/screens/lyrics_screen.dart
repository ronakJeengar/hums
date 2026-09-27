import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/core/theme/app_icons.dart';
import 'package:hums_mobile/core/widgets/app_icon.dart';
import 'package:hums_mobile/features/audio_player/presentation/providers/audio_player_provider.dart';
import 'package:hums_mobile/features/lyrics/domain/entities/lyrics_entity.dart';
import 'package:hums_mobile/features/lyrics/presentation/providers/lyrics_provider.dart';
import 'package:hums_mobile/features/lyrics/presentation/states/lyrics_state.dart';
import 'package:hums_mobile/features/lyrics/presentation/widgets/lyric_line_tile.dart';

class LyricsScreen extends ConsumerStatefulWidget {
  final String? trackId;

  const LyricsScreen({
    super.key,
    this.trackId,
  });

  @override
  ConsumerState<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends ConsumerState<LyricsScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isUserScrolling = false;
  Timer? _resumeAutoScrollTimer;
  int _lastAutoScrolledIndex = -1;

  @override
  void dispose() {
    _scrollController.dispose();
    _resumeAutoScrollTimer?.cancel();
    super.dispose();
  }

  void _onUserInteracted() {
    setState(() {
      _isUserScrolling = true;
    });
    _resumeAutoScrollTimer?.cancel();
    _resumeAutoScrollTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _isUserScrolling = false;
        });
      }
    });
  }

  void _jumpToCurrentLine(int activeIndex) {
    setState(() {
      _isUserScrolling = false;
    });
    _resumeAutoScrollTimer?.cancel();
    _scrollToIndex(activeIndex);
  }

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients || index < 0) return;

    // Approximate line height (tile height ~56px)
    final targetOffset = (index * 60.0) - 140.0;
    final clampedOffset = targetOffset.clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    _scrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(audioPlayerNotifierProvider);
    final effectiveTrackId = widget.trackId ?? playerState.track?.trackId;

    if (effectiveTrackId == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const AppIcon(
              icon: AppIcons.close,
              size: 22,
              color: AppColors.textPrimary,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(
          child: Text(
            'No track selected',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
          ),
        ),
      );
    }

    final lyricsState = ref.watch(lyricsNotifierProvider(effectiveTrackId));
    final activeIndex = ref.watch(activeLyricLineIndexProvider(effectiveTrackId));

    // Handle auto-scroll when active line index changes
    if (!_isUserScrolling &&
        activeIndex >= 0 &&
        activeIndex != _lastAutoScrolledIndex) {
      _lastAutoScrolledIndex = activeIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToIndex(activeIndex);
      });
    }

    final track = playerState.track;
    final trackTitle = track?.title ?? 'Track';
    final artistName = track?.artistName ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const AppIcon(
                      icon: AppIcons.close,
                      size: 22,
                      color: AppColors.textPrimary,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trackTitle,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (artistName.isNotEmpty)
                          Text(
                            artistName,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (lyricsState.lyrics != null)
                    _buildLyricsBadge(lyricsState.lyrics!),
                ],
              ),
            ),
            const Divider(color: AppColors.surfaceHighlight, height: 1),

            // Content Area
            Expanded(
              child: Stack(
                children: [
                  _buildContent(
                    context,
                    effectiveTrackId,
                    lyricsState,
                    activeIndex,
                  ),

                  // Floating "Jump to current" button when manually scrolled away
                  if (_isUserScrolling &&
                      activeIndex >= 0 &&
                      lyricsState.lyrics?.hasSynchronizedLines == true)
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: ElevatedButton.icon(
                          onPressed: () => _jumpToCurrentLine(activeIndex),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.background,
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            elevation: 6,
                          ),
                          icon: const Icon(Icons.sync, size: 18),
                          label: const Text(
                            'Jump to current line',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Mini player controls bar at bottom
            if (playerState.hasTrack)
              _buildMiniControls(context, playerState),
          ],
        ),
      ),
    );
  }

  Widget _buildLyricsBadge(LyricsEntity lyrics) {
    final isSync = lyrics.hasSynchronizedLines;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isSync
            ? AppColors.primary.withValues(alpha: 0.15)
            : AppColors.surfaceHighlight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSync
              ? AppColors.primary.withValues(alpha: 0.4)
              : AppColors.border,
        ),
      ),
      child: Text(
        isSync ? 'SYNCHRONIZED' : 'PLAIN LYRICS',
        style: TextStyle(
          color: isSync ? AppColors.primaryLight : AppColors.textTertiary,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    String trackId,
    LyricsState state,
    int activeIndex,
  ) {
    if (state.isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
            SizedBox(height: 16),
            Text(
              'Loading lyrics...',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (state.isProcessing) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryLight),
              ),
              const SizedBox(height: 20),
              const Text(
                'Generating lyrics with AI...',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Analyzing audio and aligning line-by-line timestamps. This may take a moment.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (state.isError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                state.errorMessage ?? 'Unable to load lyrics.',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref
                      .read(lyricsNotifierProvider(trackId).notifier)
                      .fetchLyrics(forceRefresh: true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.background,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final lyrics = state.lyrics;
    if (state.isUnavailable || lyrics == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.music_off_outlined,
                size: 48,
                color: AppColors.textTertiary,
              ),
              const SizedBox(height: 16),
              const Text(
                'No lyrics available',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Lyrics have not been created yet for this track.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: state.isTriggeringGeneration
                    ? null
                    : () {
                        ref
                            .read(lyricsNotifierProvider(trackId).notifier)
                            .requestGeneration();
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.background,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                icon: state.isTriggeringGeneration
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.background,
                        ),
                      )
                    : const Icon(Icons.auto_awesome, size: 18),
                label: Text(
                  state.isTriggeringGeneration
                      ? 'Requesting AI...'
                      : 'Generate with AI',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 1. Synchronized Lyrics
    if (lyrics.hasSynchronizedLines) {
      return NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is UserScrollNotification) {
            _onUserInteracted();
          }
          return false;
        },
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          itemCount: lyrics.lines.length,
          itemBuilder: (context, index) {
            final line = lyrics.lines[index];
            final isActive = index == activeIndex;

            return LyricLineTile(
              line: line,
              isActive: isActive,
              onTap: () {
                ref
                    .read(audioPlayerNotifierProvider.notifier)
                    .seek(Duration(milliseconds: line.startMs));
              },
            );
          },
        ),
      );
    }

    // 2. Plain Text Lyrics
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Text(
        lyrics.text ?? 'No lyrics available',
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          height: 1.8,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildMiniControls(BuildContext context, dynamic playerState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  playerState.track?.title ?? '',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDuration(playerState.position),
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const AppIcon(
              icon: AppIcons.seekBackward10,
              size: 22,
              color: AppColors.textPrimary,
            ),
            onPressed: () {
              ref.read(audioPlayerNotifierProvider.notifier).seekBackward10();
            },
          ),
          IconButton(
            icon: AppIcon(
              icon: playerState.isPlaying ? AppIcons.pause : AppIcons.play,
              size: 28,
              color: AppColors.primaryLight,
            ),
            onPressed: () {
              ref.read(audioPlayerNotifierProvider.notifier).togglePlayPause();
            },
          ),
          IconButton(
            icon: const AppIcon(
              icon: AppIcons.seekForward30,
              size: 22,
              color: AppColors.textPrimary,
            ),
            onPressed: () {
              ref.read(audioPlayerNotifierProvider.notifier).seekForward30();
            },
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
