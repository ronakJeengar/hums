import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/core/theme/app_spacing.dart';
import 'package:hums_mobile/features/notifications/presentation/providers/notification_provider.dart';

class NotificationPreferencesModal extends ConsumerStatefulWidget {
  const NotificationPreferencesModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const NotificationPreferencesModal(),
    );
  }

  @override
  ConsumerState<NotificationPreferencesModal> createState() =>
      _NotificationPreferencesModalState();
}

class _NotificationPreferencesModalState
    extends ConsumerState<NotificationPreferencesModal> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(notificationPreferencesNotifierProvider.notifier).loadPreferences();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationPreferencesNotifierProvider);
    final notifier = ref.read(notificationPreferencesNotifierProvider.notifier);
    final prefs = state.preferences;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
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
              const Text(
                'Notification Preferences',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Choose the notifications you want to receive on this device.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(color: AppColors.divider),

          if (state.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else ...[
            // Master toggle
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: AppColors.primary,
              title: const Text(
                'Allow Push Notifications',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                'Receive notifications even when the app is closed',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              value: prefs.pushEnabled,
              onChanged: (val) {
                notifier.updatePreferences(prefs.copyWith(pushEnabled: val));
              },
            ),
            const Divider(color: AppColors.divider),

            // Category: Processing
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: AppColors.primary,
              title: const Text(
                'Audio Processing & Uploads',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              subtitle: const Text(
                'Get notified when your tracks finish transcoding',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              value: prefs.pushEnabled && prefs.processingUpdatesEnabled,
              onChanged: prefs.pushEnabled
                  ? (val) {
                      notifier.updatePreferences(
                        prefs.copyWith(processingUpdatesEnabled: val),
                      );
                    }
                  : null,
            ),

            // Category: New Releases
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: AppColors.primary,
              title: const Text(
                'New Releases',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              subtitle: const Text(
                'Updates when artists you follow drop new music',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              value: prefs.pushEnabled && prefs.newReleasesEnabled,
              onChanged: prefs.pushEnabled
                  ? (val) {
                      notifier.updatePreferences(
                        prefs.copyWith(newReleasesEnabled: val),
                      );
                    }
                  : null,
            ),

            // Category: Playlists
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: AppColors.primary,
              title: const Text(
                'Playlist Updates',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              subtitle: const Text(
                'Changes in followed and collaborative playlists',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              value: prefs.pushEnabled && prefs.playlistUpdatesEnabled,
              onChanged: prefs.pushEnabled
                  ? (val) {
                      notifier.updatePreferences(
                        prefs.copyWith(playlistUpdatesEnabled: val),
                      );
                    }
                  : null,
            ),

            // Category: Recommendations
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: AppColors.primary,
              title: const Text(
                'AI Recommendations',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              subtitle: const Text(
                'Weekly mixes and smart track recommendations',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              value: prefs.pushEnabled && prefs.recommendationsEnabled,
              onChanged: prefs.pushEnabled
                  ? (val) {
                      notifier.updatePreferences(
                        prefs.copyWith(recommendationsEnabled: val),
                      );
                    }
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}
