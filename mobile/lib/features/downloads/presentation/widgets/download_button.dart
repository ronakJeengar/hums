import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/core/theme/app_spacing.dart';
import 'package:hums_mobile/core/theme/app_typography.dart';
import 'package:hums_mobile/features/downloads/domain/entities/download_status.dart';
import 'package:hums_mobile/features/downloads/presentation/providers/download_manager_provider.dart';

/// Contextual download button that dynamically reflects download state:
/// not downloaded -> queued -> downloading (%) -> completed -> paused -> failed.
class DownloadButton extends ConsumerWidget {
  final String trackId;
  final String? title;
  final String? artistName;
  final String? albumName;
  final int? durationSeconds;
  final String? artworkUrl;
  final double size;
  final Color? color;

  const DownloadButton({
    super.key,
    required this.trackId,
    this.title,
    this.artistName,
    this.albumName,
    this.durationSeconds,
    this.artworkUrl,
    this.size = AppSpacing.iconMd,
    this.color,
  });

  void _onPressed(BuildContext context, WidgetRef ref, DownloadStatus? status) {
    final manager = ref.read(downloadManagerProvider.notifier);

    switch (status) {
      case DownloadStatus.completed:
        _showCompletedOptions(context, ref);
        break;
      case DownloadStatus.downloading:
        manager.pauseDownload(trackId);
        break;
      case DownloadStatus.queued:
        manager.cancelDownload(trackId);
        break;
      case DownloadStatus.paused:
        manager.resumeDownload(trackId);
        break;
      case DownloadStatus.failed:
        manager.retryDownload(trackId);
        break;
      case DownloadStatus.cancelled:
      case DownloadStatus.removing:
      case null:
        manager.enqueueDownload(
          trackId: trackId,
          title: title,
          artistName: artistName,
          albumName: albumName,
          durationSeconds: durationSeconds,
          artworkUrl: artworkUrl,
        );
        break;
    }
  }

  void _showCompletedOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title ?? 'Downloaded Track',
                style: AppTypography.titleMedium.copyWith(color: AppColors.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Available for offline playback',
                style: AppTypography.labelSmall.copyWith(color: AppColors.success),
              ),
              const Divider(color: AppColors.divider, height: AppSpacing.lg),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.error),
                title: Text(
                  'Remove Download',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.error),
                ),
                contentPadding: EdgeInsets.zero,
                onTap: () {
                  Navigator.of(ctx).pop();
                  ref.read(downloadManagerProvider.notifier).removeDownload(trackId);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadState = ref.watch(downloadManagerProvider);
    final item = downloadState.items[trackId];
    final status = item?.status;
    final progress = item?.progress ?? 0.0;
    final effectiveColor = color ?? AppColors.textSecondary;

    switch (status) {
      case DownloadStatus.completed:
        return IconButton(
          iconSize: size,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          tooltip: 'Downloaded for offline',
          icon: const Icon(
            Icons.check_circle,
            color: AppColors.success,
          ),
          onPressed: () => _onPressed(context, ref, status),
        );

      case DownloadStatus.downloading:
        return InkWell(
          onTap: () => _onPressed(context, ref, status),
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress > 0 ? progress : null,
                  strokeWidth: 2.5,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  backgroundColor: AppColors.surfaceHighlight,
                ),
                Icon(
                  Icons.pause,
                  size: size * 0.5,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        );

      case DownloadStatus.queued:
        return InkWell(
          onTap: () => _onPressed(context, ref, status),
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          child: SizedBox(
            width: size,
            height: size,
            child: const Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  strokeWidth: 2.0,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.textTertiary),
                ),
                Icon(
                  Icons.hourglass_empty,
                  size: 12,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
        );

      case DownloadStatus.paused:
        return IconButton(
          iconSize: size,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          tooltip: 'Download paused - tap to resume',
          icon: const Icon(
            Icons.play_circle_outline,
            color: AppColors.warning,
          ),
          onPressed: () => _onPressed(context, ref, status),
        );

      case DownloadStatus.failed:
        return IconButton(
          iconSize: size,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          tooltip: 'Download failed - tap to retry',
          icon: const Icon(
            Icons.error_outline,
            color: AppColors.error,
          ),
          onPressed: () => _onPressed(context, ref, status),
        );

      case DownloadStatus.cancelled:
      case DownloadStatus.removing:
      case null:
        return IconButton(
          iconSize: size,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          tooltip: 'Download track',
          icon: Icon(
            Icons.arrow_circle_down_outlined,
            color: effectiveColor,
          ),
          onPressed: () => _onPressed(context, ref, status),
        );
    }
  }
}
