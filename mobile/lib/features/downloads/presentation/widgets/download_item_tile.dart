import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/core/theme/app_spacing.dart';
import 'package:hums_mobile/core/theme/app_typography.dart';
import 'package:hums_mobile/features/audio_player/presentation/providers/audio_player_provider.dart';
import 'package:hums_mobile/features/downloads/domain/entities/download_item.dart';
import 'package:hums_mobile/features/downloads/domain/entities/download_status.dart';
import 'package:hums_mobile/features/downloads/presentation/providers/download_manager_provider.dart';

/// List tile representing a single download item with state actions
/// (play, pause, resume, cancel, remove).
class DownloadItemTile extends ConsumerWidget {
  final DownloadItem item;

  const DownloadItemTile({
    super.key,
    required this.item,
  });

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double d = bytes.toDouble();
    while (d >= 1024 && i < suffixes.length - 1) {
      d /= 1024;
      i++;
    }
    return '${d.toStringAsFixed(1)} ${suffixes[i]}';
  }

  String _buildMetadataString() {
    final parts = <String>[];
    if (item.artistName != null && item.artistName!.isNotEmpty) {
      parts.add(item.artistName!);
    }
    if (item.audioBitrate != null) {
      parts.add('${item.audioBitrate} kbps');
    }
    if (item.totalBytes > 0) {
      parts.add(_formatBytes(item.totalBytes));
    }
    return parts.join(' • ');
  }

  Widget _buildTrailing(BuildContext context, WidgetRef ref) {
    final manager = ref.read(downloadManagerProvider.notifier);

    switch (item.status) {
      case DownloadStatus.completed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_circle_fill, color: AppColors.primary, size: 28),
              onPressed: () {
                ref.read(audioPlayerNotifierProvider.notifier).playTrack(item.trackId);
              },
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
              color: AppColors.surfaceElevated,
              onSelected: (value) {
                if (value == 'remove') {
                  manager.removeDownload(item.trackId);
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'remove',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                      SizedBox(width: 8),
                      Text('Remove Download', style: TextStyle(color: AppColors.error)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );

      case DownloadStatus.downloading:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.pause, color: AppColors.warning),
              tooltip: 'Pause',
              onPressed: () => manager.pauseDownload(item.trackId),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: AppColors.textTertiary),
              tooltip: 'Cancel',
              onPressed: () => manager.cancelDownload(item.trackId),
            ),
          ],
        );

      case DownloadStatus.paused:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_arrow, color: AppColors.primary),
              tooltip: 'Resume',
              onPressed: () => manager.resumeDownload(item.trackId),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: AppColors.textTertiary),
              tooltip: 'Cancel',
              onPressed: () => manager.cancelDownload(item.trackId),
            ),
          ],
        );

      case DownloadStatus.failed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.refresh, color: AppColors.error),
              tooltip: 'Retry',
              onPressed: () => manager.retryDownload(item.trackId),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.textTertiary),
              tooltip: 'Dismiss',
              onPressed: () => manager.removeDownload(item.trackId),
            ),
          ],
        );

      case DownloadStatus.queued:
        return IconButton(
          icon: const Icon(Icons.close, color: AppColors.textTertiary),
          tooltip: 'Cancel',
          onPressed: () => manager.cancelDownload(item.trackId),
        );

      case DownloadStatus.cancelled:
      case DownloadStatus.removing:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = _buildMetadataString();

    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceHighlight,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: item.artworkUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    child: Image.network(
                      item.artworkUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.music_note,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  )
                : const Icon(
                    Icons.music_note,
                    color: AppColors.primary,
                  ),
          ),
          title: Text(
            item.title,
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (meta.isNotEmpty)
                Text(
                  meta,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              if (item.status == DownloadStatus.downloading)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Downloading ${(item.progress * 100).toStringAsFixed(0)}% (${_formatBytes(item.bytesDownloaded)} / ${_formatBytes(item.totalBytes)})',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.primaryLight,
                      fontSize: 11,
                    ),
                  ),
                )
              else if (item.status == DownloadStatus.queued)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Queued in line...',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                )
              else if (item.status == DownloadStatus.paused)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Paused (${(item.progress * 100).toStringAsFixed(0)}%)',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.warning,
                      fontSize: 11,
                    ),
                  ),
                )
              else if (item.status == DownloadStatus.failed)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    item.error ?? 'Download failed',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.error,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
          trailing: _buildTrailing(context, ref),
          onTap: item.status == DownloadStatus.completed
              ? () {
                  ref.read(audioPlayerNotifierProvider.notifier).playTrack(item.trackId);
                }
              : null,
        ),
        if (item.status == DownloadStatus.downloading ||
            item.status == DownloadStatus.paused)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: LinearProgressIndicator(
              value: item.progress > 0 ? item.progress : null,
              backgroundColor: AppColors.surfaceHighlight,
              valueColor: AlwaysStoppedAnimation<Color>(
                item.status == DownloadStatus.paused
                    ? AppColors.warning
                    : AppColors.primary,
              ),
              minHeight: 2,
            ),
          ),
        const Divider(color: AppColors.divider, height: 1),
      ],
    );
  }
}
