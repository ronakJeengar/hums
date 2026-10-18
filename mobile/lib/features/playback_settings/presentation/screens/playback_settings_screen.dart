import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/core/theme/app_spacing.dart';
import 'package:hums_mobile/core/theme/app_typography.dart';
import 'package:hums_mobile/core/widgets/hums_app_bar.dart';
import 'package:hums_mobile/features/playback_settings/domain/entities/playback_quality_resolver.dart';
import 'package:hums_mobile/features/playback_settings/domain/entities/playback_settings_entity.dart';
import 'package:hums_mobile/features/playback_settings/presentation/providers/playback_settings_provider.dart';

class PlaybackSettingsScreen extends ConsumerWidget {
  const PlaybackSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(playbackSettingsNotifierProvider);
    final notifier = ref.read(playbackSettingsNotifierProvider.notifier);
    final networkType = ref.watch(networkTypeProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const HumsAppBar(
        title: 'Audio Quality & Data Saver',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Network Status Badge
            _buildNetworkStatusBadge(networkType),
            const SizedBox(height: AppSpacing.lg),

            // Section 1: Data Saver
            _buildSectionHeader('DATA USAGE'),
            const SizedBox(height: AppSpacing.sm),
            _buildDataSaverTile(settings, notifier),
            const SizedBox(height: AppSpacing.xl),

            // Section 2: Streaming Preferences
            _buildSectionHeader('STREAMING QUALITY'),
            const SizedBox(height: AppSpacing.sm),
            _buildCard(
              children: [
                _buildDropdownRow(
                  title: 'Default Streaming Quality',
                  subtitle: settings.streamingQuality.description,
                  currentValue: settings.streamingQuality,
                  allowedValues: [
                    AudioQuality.auto,
                    AudioQuality.high,
                    AudioQuality.medium,
                    AudioQuality.low,
                  ],
                  onChanged: (val) => notifier.setStreamingQuality(val),
                ),
                const Divider(color: AppColors.border, height: 1),
                _buildDropdownRow(
                  title: 'Cellular / Mobile Data',
                  subtitle: settings.dataSaverEnabled
                      ? 'Overridden to Low (64 kbps) while Data Saver is ON'
                      : settings.mobileDataQuality.description,
                  currentValue: settings.mobileDataQuality,
                  allowedValues: [
                    AudioQuality.high,
                    AudioQuality.medium,
                    AudioQuality.low,
                  ],
                  enabled: !settings.dataSaverEnabled,
                  onChanged: (val) => notifier.setMobileDataQuality(val),
                ),
                const Divider(color: AppColors.border, height: 1),
                _buildDropdownRow(
                  title: 'Wi-Fi Streaming',
                  subtitle: settings.wifiQuality.description,
                  currentValue: settings.wifiQuality,
                  allowedValues: [
                    AudioQuality.auto,
                    AudioQuality.high,
                    AudioQuality.medium,
                    AudioQuality.low,
                  ],
                  onChanged: (val) => notifier.setWifiQuality(val),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // Section 3: Downloads
            _buildSectionHeader('OFFLINE DOWNLOADS'),
            const SizedBox(height: AppSpacing.sm),
            _buildCard(
              children: [
                _buildDropdownRow(
                  title: 'Download Audio Quality',
                  subtitle:
                      '${settings.downloadQuality.label} · ${PlaybackQualityResolver.formatEstimatedSizeMbPerMinute(settings.downloadQuality)}',
                  currentValue: settings.downloadQuality,
                  allowedValues: [
                    AudioQuality.high,
                    AudioQuality.medium,
                    AudioQuality.low,
                  ],
                  onChanged: (val) => notifier.setDownloadQuality(val),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 16,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Changing download quality applies to future downloads. Existing offline tracks are preserved at their downloaded bitrate.',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.textTertiary,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildNetworkStatusBadge(NetworkType networkType) {
    final (icon, label, color) = switch (networkType) {
      NetworkType.wifi => (Icons.wifi, 'Connected to Wi-Fi', AppColors.success),
      NetworkType.mobile => (
          Icons.signal_cellular_alt,
          'Using Cellular Mobile Data',
          AppColors.warning
        ),
      NetworkType.offline => (
          Icons.cloud_off,
          'Offline Mode · Local Storage Only',
          AppColors.error
        ),
      NetworkType.unknown => (
          Icons.network_check,
          'Network Detecting',
          AppColors.textTertiary
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: AppTypography.labelLarge.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildDataSaverTile(
      PlaybackSettingsEntity settings, PlaybackSettingsNotifier notifier) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: settings.dataSaverEnabled
              ? AppColors.primary.withValues(alpha: 0.5)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: settings.dataSaverEnabled
                  ? AppColors.primary.withValues(alpha: 0.2)
                  : AppColors.surfaceHighlight,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.data_saver_on,
              color: settings.dataSaverEnabled
                  ? AppColors.primary
                  : AppColors.textSecondary,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Data Saver',
                  style: AppTypography.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  'Forces audio playback to 64 kbps on cellular data to preserve bandwidth.',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Switch(
            value: settings.dataSaverEnabled,
            onChanged: (val) => notifier.setDataSaver(val),
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownRow({
    required String title,
    required String subtitle,
    required AudioQuality currentValue,
    required List<AudioQuality> allowedValues,
    required ValueChanged<AudioQuality> onChanged,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: enabled
                        ? AppColors.textPrimary
                        : AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          DropdownButton<AudioQuality>(
            value: allowedValues.contains(currentValue)
                ? currentValue
                : allowedValues.first,
            dropdownColor: AppColors.surfaceElevated,
            underline: const SizedBox.shrink(),
            icon: const Icon(
              Icons.arrow_drop_down,
              color: AppColors.primary,
            ),
            onChanged: enabled
                ? (AudioQuality? val) {
                    if (val != null) {
                      onChanged(val);
                    }
                  }
                : null,
            items: allowedValues.map((q) {
              return DropdownMenuItem<AudioQuality>(
                value: q,
                child: Text(
                  q.label,
                  style: TextStyle(
                    color: enabled
                        ? AppColors.textPrimary
                        : AppColors.textTertiary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
