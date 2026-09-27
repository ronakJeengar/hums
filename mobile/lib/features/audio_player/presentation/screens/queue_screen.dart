import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/core/theme/app_icons.dart';
import 'package:hums_mobile/core/widgets/app_icon.dart';
import 'package:hums_mobile/features/audio_player/domain/entities/player_queue.dart';
import 'package:hums_mobile/features/audio_player/presentation/providers/audio_player_provider.dart';
import 'package:hums_mobile/features/library/presentation/widgets/like_button.dart';

class QueueScreen extends ConsumerWidget {
  const QueueScreen({super.key});

  String _formatDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return '--:--';
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remSecs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remSecs';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(audioPlayerNotifierProvider);
    final notifier = ref.read(audioPlayerNotifierProvider.notifier);

    final track = playerState.track;
    final queue = playerState.queue;
    final manualQueue = playerState.manualQueue;
    final upNextQueue = playerState.upNextQueue;
    final smartQueue = playerState.smartQueue;
    final isShuffled = playerState.isShuffled;
    final repeatMode = playerState.repeatMode;

    final hasUpcoming = manualQueue.isNotEmpty ||
        upNextQueue.isNotEmpty ||
        smartQueue.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'Queue & Up Next',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const AppIcon(
            icon: AppIcons.back,
            size: 20,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // Shuffle Button
          IconButton(
            tooltip: isShuffled ? 'Shuffle: On' : 'Shuffle: Off',
            icon: Icon(
              Icons.shuffle,
              size: 22,
              color: isShuffled ? AppColors.primaryLight : AppColors.textTertiary,
            ),
            onPressed: () => notifier.toggleShuffle(),
          ),

          // Repeat Mode Button
          IconButton(
            tooltip: switch (repeatMode) {
              PlaybackRepeatMode.repeatTrack => 'Repeat: Current Track',
              PlaybackRepeatMode.repeatQueue => 'Repeat: Entire Queue',
              PlaybackRepeatMode.off => 'Repeat: Off',
            },
            icon: Icon(
              repeatMode == PlaybackRepeatMode.repeatTrack
                  ? Icons.repeat_one
                  : Icons.repeat,
              size: 22,
              color: repeatMode != PlaybackRepeatMode.off
                  ? AppColors.primaryLight
                  : AppColors.textTertiary,
            ),
            onPressed: () => notifier.cycleRepeatMode(),
          ),

          // Clear All Button
          if (hasUpcoming)
            TextButton(
              onPressed: () => notifier.clearAllUpcomingQueue(),
              child: const Text(
                'Clear All',
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: track == null
          ? _buildEmptyState()
          : CustomScrollView(
              slivers: [
                // 1. Now Playing Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: _buildNowPlayingCard(track, playerState.isPlaying),
                  ),
                ),

                // 2. Manual User Queue Section
                if (manualQueue.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Next In Queue',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${manualQueue.length}',
                                  style: const TextStyle(
                                    color: AppColors.primaryLight,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: () => notifier.clearManualQueue(),
                            child: const Text(
                              'Clear',
                              style: TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverReorderableList(
                    itemCount: manualQueue.length,
                    onReorder: (oldIndex, newIndex) {
                      notifier.reorderManualQueue(oldIndex, newIndex);
                    },
                    itemBuilder: (context, index) {
                      final item = manualQueue[index];
                      return _buildQueueTile(
                        key: ValueKey('manual_${item.queueItemId}'),
                        index: index,
                        item: item,
                        isManual: true,
                        onTap: () => notifier.playTrack(item.trackId),
                        onRemove: () =>
                            notifier.removeQueueItem(item.queueItemId),
                      );
                    },
                  ),
                ],

                // 3. Up Next From Source Section
                if (upNextQueue.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                      child: Row(
                        children: [
                          Text(
                            queue?.playlistName != null
                                ? 'Next from ${queue!.playlistName}'
                                : 'Up Next',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceHighlight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${upNextQueue.length}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverReorderableList(
                    itemCount: upNextQueue.length,
                    onReorder: (oldIndex, newIndex) {
                      notifier.reorderUpNextQueue(oldIndex, newIndex);
                    },
                    itemBuilder: (context, index) {
                      final item = upNextQueue[index];
                      return _buildQueueTile(
                        key: ValueKey('upnext_${item.queueItemId}'),
                        index: index,
                        item: item,
                        isManual: false,
                        onTap: () => notifier.playTrack(item.trackId),
                        onRemove: () =>
                            notifier.removeQueueItem(item.queueItemId),
                      );
                    },
                  ),
                ],

                // 4. Smart Queue / Auto Up Next Recommendations
                if (smartQueue.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            size: 16,
                            color: AppColors.primaryLight,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Smart Up Next',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Continuous Play',
                              style: TextStyle(
                                color: AppColors.primaryLight,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = smartQueue[index];
                        return _buildSmartQueueTile(
                          context: context,
                          item: item,
                          notifier: notifier,
                        );
                      },
                      childCount: smartQueue.length,
                    ),
                  ),
                ],

                // Bottom padding
                const SliverToBoxAdapter(
                  child: SizedBox(height: 48),
                ),
              ],
            ),
    );
  }

  Widget _buildNowPlayingCard(dynamic track, bool isPlaying) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Album / Vinyl Icon with subtle play indicator
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.surfaceHighlight,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: isPlaying
                ? const Icon(
                    Icons.graphic_eq,
                    size: 26,
                    color: AppColors.primaryLight,
                  )
                : const AppIcon(
                    icon: AppIcons.musicNote,
                    size: 24,
                    color: AppColors.primaryLight,
                  ),
          ),
          const SizedBox(width: 14),

          // Track Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'NOW PLAYING',
                  style: TextStyle(
                    color: AppColors.primaryLight,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  track.title as String,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  (track.artistName as String?) ?? 'Unknown Artist',
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

          // Like Button
          LikeButton(
            trackId: track.trackId as String,
            size: 22,
          ),
        ],
      ),
    );
  }

  Widget _buildQueueTile({
    required Key key,
    required int index,
    required QueueItem item,
    required bool isManual,
    required VoidCallback onTap,
    required VoidCallback onRemove,
  }) {
    return Container(
      key: key,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: ReorderableDragStartListener(
          index: index,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              Icons.drag_indicator,
              color: AppColors.textTertiary,
              size: 20,
            ),
          ),
        ),
        title: Text(
          item.title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Expanded(
              child: Text(
                item.artistName ?? 'Unknown Artist',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isManual) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Added',
                  style: TextStyle(
                    color: AppColors.primaryLight,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatDuration(item.durationSeconds),
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(
                Icons.close,
                size: 18,
                color: AppColors.textTertiary,
              ),
              onPressed: onRemove,
              splashRadius: 18,
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildSmartQueueTile({
    required BuildContext context,
    required QueueItem item,
    required AudioPlayerNotifier notifier,
  }) {
    final sourceLabel = switch (item.source) {
      'genre_match' => 'Matching Genre',
      'artist_match' => 'Same Artist',
      'personalized' => 'For You',
      'trending' => 'Trending',
      _ => 'Suggested',
    };

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.15),
          width: 0.8,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.auto_awesome,
            size: 18,
            color: AppColors.primaryLight,
          ),
        ),
        title: Text(
          item.title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Expanded(
              child: Text(
                item.artistName ?? 'Unknown Artist',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.surfaceHighlight,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                sourceLabel,
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Play Next',
              icon: const Icon(
                Icons.playlist_play,
                size: 22,
                color: AppColors.primaryLight,
              ),
              onPressed: () {
                notifier.playNext(item);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Playing next: ${item.title}'),
                    duration: const Duration(seconds: 2),
                    backgroundColor: AppColors.surfaceElevated,
                  ),
                );
              },
              splashRadius: 18,
            ),
            IconButton(
              tooltip: 'Remove',
              icon: const Icon(
                Icons.close,
                size: 18,
                color: AppColors.textTertiary,
              ),
              onPressed: () => notifier.removeQueueItem(item.queueItemId),
              splashRadius: 18,
            ),
          ],
        ),
        onTap: () => notifier.playTrack(item.trackId),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surfaceHighlight,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.queue_music,
                size: 36,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Your Queue is Empty',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Play tracks from playlists, search, recommendations, or your library to populate the queue.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
