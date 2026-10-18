import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/core/theme/app_spacing.dart';
import 'package:hums_mobile/core/theme/app_typography.dart';
import 'package:hums_mobile/core/widgets/hums_app_bar.dart';
import 'package:hums_mobile/core/widgets/hums_button.dart';
import 'package:hums_mobile/features/subscriptions/domain/entities/user_subscription_entity.dart';
import 'package:hums_mobile/features/subscriptions/presentation/providers/subscription_provider.dart';
import 'package:hums_mobile/features/subscriptions/presentation/widgets/premium_badge.dart';
import 'package:hums_mobile/routing/route_names.dart';

class SubscriptionStatusScreen extends ConsumerStatefulWidget {
  const SubscriptionStatusScreen({super.key});

  @override
  ConsumerState<SubscriptionStatusScreen> createState() =>
      _SubscriptionStatusScreenState();
}

class _SubscriptionStatusScreenState
    extends ConsumerState<SubscriptionStatusScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(subscriptionNotifierProvider.notifier).loadSubscriptionData();
    });
  }

  String _formatDate(DateTime dt) {
    final year = dt.year;
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  void _showManageSubscriptionDialog() {
    final isIOS = Platform.isIOS;
    final isAndroid = Platform.isAndroid;
    final storeName = isIOS
        ? 'Apple App Store'
        : isAndroid
            ? 'Google Play Store'
            : 'Store';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Text(
          'Manage on $storeName',
          style: AppTypography.titleMedium,
        ),
        content: Text(
          isIOS
              ? 'To update, pause, or cancel your subscription, open your iPhone Settings > Apple Account > Subscriptions > Hums.'
              : isAndroid
                  ? 'To update, pause, or cancel your subscription, open Google Play Store > Profile > Payments & subscriptions > Subscriptions > Hums.'
                  : 'Manage your active subscription in your device app store settings.',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Understood',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subState = ref.watch(subscriptionNotifierProvider);

    // Listen to messages
    ref.listen(subscriptionNotifierProvider, (previous, next) {
      if (next.successMessage != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.successMessage!),
            backgroundColor: AppColors.success,
          ),
        );
        ref.read(subscriptionNotifierProvider.notifier).clearMessages();
      } else if (next.errorMessage != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.error,
          ),
        );
        ref.read(subscriptionNotifierProvider.notifier).clearMessages();
      }
    });

    final sub = subState.currentSubscription;
    final isPremium = subState.isPremium;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: HumsAppBar(
        title: 'Subscription',
        actions: [
          TextButton(
            onPressed: subState.isRestoring
                ? null
                : () => ref
                    .read(subscriptionNotifierProvider.notifier)
                    .restorePurchases(),
            child: subState.isRestoring
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : Text(
                    'Restore',
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
          ),
        ],
      ),
      body: subState.isLoading && sub == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: isPremium && sub != null
                  ? _buildPremiumContent(sub, subState.isRestoring)
                  : _buildFreeContent(subState.isRestoring),
            ),
    );
  }

  Widget _buildPremiumContent(UserSubscriptionEntity sub, bool isRestoring) {
    final isCanceled = sub.isCanceled;
    final isInGracePeriod = sub.isInGracePeriod;

    Color statusColor = AppColors.success;
    if (isInGracePeriod || isCanceled) {
      statusColor = AppColors.warning;
    } else if (sub.isExpired || sub.isRevoked) {
      statusColor = AppColors.error;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: AppSpacing.sm),
        const PremiumBadge(size: PremiumBadgeSize.large),
        const SizedBox(height: AppSpacing.md),
        Text(
          sub.planName.isNotEmpty ? sub.planName : 'Hums Premium',
          style: AppTypography.headlineMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            border: Border.all(color: statusColor.withValues(alpha: 0.4)),
          ),
          child: Text(
            sub.statusDisplayLabel.toUpperCase(),
            style: AppTypography.labelSmall.copyWith(
              color: statusColor,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // Billing Details Card
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _buildDetailRow(
                icon: Icons.storefront_rounded,
                label: 'Billing Provider',
                value: sub.provider.toUpperCase(),
              ),
              const Divider(color: AppColors.border, height: AppSpacing.lg),
              _buildDetailRow(
                icon: Icons.calendar_today_rounded,
                label: 'Started On',
                value: _formatDate(sub.currentPeriodStart),
              ),
              const Divider(color: AppColors.border, height: AppSpacing.lg),
              _buildDetailRow(
                icon: Icons.event_repeat_rounded,
                label: isCanceled ? 'Access Ends' : 'Renews On',
                value: _formatDate(sub.effectiveExpiryDate),
              ),
              if (sub.cancelAtPeriodEnd) ...[
                const Divider(color: AppColors.border, height: AppSpacing.lg),
                _buildDetailRow(
                  icon: Icons.info_outline_rounded,
                  label: 'Renewal State',
                  value: 'Will not renew automatically',
                  valueColor: AppColors.warning,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Active Entitlements Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ACTIVE PREMIUM ENTITLEMENTS',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _buildEntitlementItem(
                'Studio High Fidelity (192 kbps)',
                'Lossless-grade AAC acoustic streaming',
              ),
              _buildEntitlementItem(
                'Offline Downloads & Storage',
                'Download any track for network-free listening',
              ),
              _buildEntitlementItem(
                'Completely Ad-Free Audio',
                'Uninterrupted playback without sponsor messages',
              ),
              _buildEntitlementItem(
                'Unlimited Library & Playlists',
                'No caps on saved favorites or custom playlists',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // Manage button
        SizedBox(
          width: double.infinity,
          child: HumsButton(
            label: 'Manage Subscription',
            icon: Icons.settings_rounded,
            variant: HumsButtonVariant.secondary,
            onPressed: _showManageSubscriptionDialog,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Change plan / Upgrade button
        SizedBox(
          width: double.infinity,
          child: HumsButton(
            label: 'Change Plan',
            icon: Icons.swap_horiz_rounded,
            variant: HumsButtonVariant.outline,
            onPressed: () => context.push(RouteNames.premiumPlansPath),
          ),
        ),
      ],
    );
  }

  Widget _buildFreeContent(bool isRestoring) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
          child: const Icon(
            Icons.music_note_rounded,
            size: 32,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Hums Free Tier',
          style: AppTypography.headlineMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Standard quality streaming with basic platform access.',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),

        // Features comparison
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'YOUR CURRENT FREE ACCESS',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _buildEntitlementItem(
                'Standard Audio Quality',
                'Streaming up to 128 kbps AAC',
                isUnlocked: true,
              ),
              _buildEntitlementItem(
                'Cloud Streaming',
                'Stream on connected mobile devices',
                isUnlocked: true,
              ),
              const Divider(color: AppColors.border, height: AppSpacing.lg),
              Text(
                'AVAILABLE WITH PREMIUM',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _buildEntitlementItem(
                'Studio High Fidelity (192 kbps)',
                'Deep acoustic warmth and crisp master clarity',
                isUnlocked: false,
              ),
              _buildEntitlementItem(
                'Offline Downloads',
                'Keep tracks saved directly on device storage',
                isUnlocked: false,
              ),
              _buildEntitlementItem(
                'Ad-Free Acoustic Flow',
                'Zero interruption experience',
                isUnlocked: false,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // Upgrade button
        SizedBox(
          width: double.infinity,
          child: HumsButton(
            label: 'Upgrade to Hums Premium',
            icon: Icons.star_rounded,
            onPressed: () => context.push(RouteNames.premiumPlansPath),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textTertiary),
        const SizedBox(width: AppSpacing.md),
        Text(
          label,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: AppTypography.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildEntitlementItem(
    String title,
    String description, {
    bool isUnlocked = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isUnlocked
                ? Icons.check_circle_rounded
                : Icons.lock_outline_rounded,
            size: 18,
            color: isUnlocked ? AppColors.primary : AppColors.textTertiary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.titleMedium.copyWith(
                    color: isUnlocked
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
                Text(
                  description,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
