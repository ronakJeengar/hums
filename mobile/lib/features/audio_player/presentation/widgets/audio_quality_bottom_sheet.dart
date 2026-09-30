import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/core/theme/app_spacing.dart';
import 'package:hums_mobile/core/theme/app_typography.dart';
import 'package:hums_mobile/features/audio_player/presentation/providers/audio_player_provider.dart';
import 'package:hums_mobile/features/playback_settings/domain/entities/playback_settings_entity.dart';

class AudioQualityBottomSheet extends ConsumerWidget {
  const AudioQualityBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const AudioQualityBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(audioPlayerNotifierProvider);
    final activeQualityStr = playerState.selectedQuality ?? 'AUTO';
    final activeBitrate = playerState.activeBitrateKbps;

    final options = [
      (
        quality: AudioQuality.auto,
        title: 'Auto',
        subtitle: 'Optimizes fidelity based on network connection',
        badge: 'Recommended',
      ),
      (
        quality: AudioQuality.high,
        title: 'High (192 kbps)',
        subtitle: 'Maximum acoustic fidelity · Uses ~1.5 MB/min',
        badge: 'HQ',
      ),
      (
        quality: AudioQuality.medium,
        title: 'Medium (128 kbps)',
        subtitle: 'Balanced fidelity and bandwidth · Uses ~1.0 MB/min',
        badge: null,
      ),
      (
        quality: AudioQuality.low,
        title: 'Low (64 kbps)',
        subtitle: 'Saves cellular data and battery · Uses ~0.5 MB/min',
        badge: 'Data Saver',
      ),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Audio Quality',
                      style: AppTypography.titleMedium,
                    ),
                    if (activeBitrate != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Currently streaming at $activeBitrate kbps AAC',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                  splashRadius: 20,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            const Divider(color: AppColors.border),
            const SizedBox(height: AppSpacing.xs),

            // Quality Options List
            ...options.map((opt) {
              final isSelected = activeQualityStr == opt.quality.toApiValue();

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await ref
                        .read(audioPlayerNotifierProvider.notifier)
                        .changeQuality(opt.quality);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.md,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textTertiary,
                          size: 22,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    opt.title,
                                    style: AppTypography.bodyLarge.copyWith(
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? AppColors.primaryLight
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                  if (opt.badge != null) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.primary
                                                .withValues(alpha: 0.2)
                                            : AppColors.surfaceHighlight,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        opt.badge!,
                                        style: TextStyle(
                                          color: isSelected
                                              ? AppColors.primary
                                              : AppColors.textTertiary,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                opt.subtitle,
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.textTertiary,
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
            }),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}
