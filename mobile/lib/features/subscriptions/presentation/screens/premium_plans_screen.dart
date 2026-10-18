import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/core/theme/app_spacing.dart';
import 'package:hums_mobile/core/theme/app_typography.dart';
import 'package:hums_mobile/core/widgets/hums_app_bar.dart';
import 'package:hums_mobile/core/widgets/hums_button.dart';
import 'package:hums_mobile/features/subscriptions/domain/entities/subscription_plan_entity.dart';
import 'package:hums_mobile/features/subscriptions/presentation/providers/subscription_provider.dart';
import 'package:hums_mobile/features/subscriptions/presentation/widgets/premium_badge.dart';

class PremiumPlansScreen extends ConsumerStatefulWidget {
  const PremiumPlansScreen({super.key});

  @override
  ConsumerState<PremiumPlansScreen> createState() => _PremiumPlansScreenState();
}

class _PremiumPlansScreenState extends ConsumerState<PremiumPlansScreen> {
  String _selectedPlanCode = 'PREMIUM_YEARLY';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(subscriptionNotifierProvider.notifier).loadSubscriptionData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final subState = ref.watch(subscriptionNotifierProvider);

    // Listen to success or error messages
    ref.listen(subscriptionNotifierProvider, (previous, next) {
      if (next.successMessage != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.successMessage!),
            backgroundColor: AppColors.success,
          ),
        );
        ref.read(subscriptionNotifierProvider.notifier).clearMessages();
        // Return to previous screen or status
        context.pop();
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

    final paidPlans = subState.plans.where((p) => !p.isFree).toList();
    paidPlans.sort((a, b) => b.priceCents.compareTo(a.priceCents));

    final selectedPlan = paidPlans.firstWhere(
      (p) => p.code == _selectedPlanCode,
      orElse: () => paidPlans.isNotEmpty ? paidPlans.first : const SubscriptionPlanEntity(
        id: '',
        code: 'PREMIUM_YEARLY',
        name: 'Hums Premium Annual',
        billingInterval: 'YEAR',
        priceCents: 9999,
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: HumsAppBar(
        title: 'Hums Premium',
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
      body: subState.isLoading && subState.plans.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: AppSpacing.sm),
                  const PremiumBadge(size: PremiumBadgeSize.medium),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Pristine Audio.\nZero Compromise.',
                    style: AppTypography.displayMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Unlock maximum audio fidelity, offline listening, and an uninterrupted acoustic experience.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Value proposition checklist
                  _buildBenefitsList(),
                  const SizedBox(height: AppSpacing.xl),

                  // Plan Selection Cards
                  if (paidPlans.isNotEmpty) ...[
                    ...paidPlans.map((plan) {
                      final isSelected = plan.code == _selectedPlanCode;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _buildPlanCard(plan, isSelected),
                      );
                    }),
                  ] else ...[
                    // Default fallback plan display if offline
                    _buildPlanCard(
                      const SubscriptionPlanEntity(
                        id: 'annual',
                        code: 'PREMIUM_YEARLY',
                        name: 'Hums Premium Annual',
                        billingInterval: 'YEAR',
                        priceCents: 9999,
                      ),
                      _selectedPlanCode == 'PREMIUM_YEARLY',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildPlanCard(
                      const SubscriptionPlanEntity(
                        id: 'monthly',
                        code: 'PREMIUM_MONTHLY',
                        name: 'Hums Premium Monthly',
                        billingInterval: 'MONTH',
                        priceCents: 999,
                      ),
                      _selectedPlanCode == 'PREMIUM_MONTHLY',
                    ),
                  ],

                  const SizedBox(height: AppSpacing.lg),

                  // Subscribe Button
                  SizedBox(
                    width: double.infinity,
                    child: HumsButton(
                      label: subState.isPurchasing
                          ? 'Verifying Purchase...'
                          : 'Get ${selectedPlan.name}',
                      icon: Icons.lock_open_rounded,
                      isLoading: subState.isPurchasing,
                      onPressed: () {
                        ref
                            .read(subscriptionNotifierProvider.notifier)
                            .purchasePlan(selectedPlan);
                      },
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Legal Disclaimers & Terms
                  Text(
                    'Subscription automatically renews unless canceled at least 24 hours prior to the end of the current period. Manage or cancel anytime in your App Store / Google Play account settings.',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
    );
  }

  Widget _buildBenefitsList() {
    final benefits = [
      (
        icon: Icons.headphones_rounded,
        title: 'Studio High Fidelity (192 kbps)',
        subtitle: 'Pristine AAC master audio with uncompromised acoustic depth.'
      ),
      (
        icon: Icons.download_done_rounded,
        title: 'Offline Downloads & Playback',
        subtitle: 'Take your favorite tracks anywhere without consuming cellular data.'
      ),
      (
        icon: Icons.block_rounded,
        title: 'Completely Ad-Free Listening',
        subtitle: 'Unbroken musical flow with zero commercial interruptions.'
      ),
      (
        icon: Icons.library_music_rounded,
        title: 'Unlimited Personal Library',
        subtitle: 'Save unlimited liked songs, custom playlists, and listening history.'
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: benefits.map((b) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(b.icon, size: 18, color: AppColors.primary),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.title, style: AppTypography.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        b.subtitle,
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPlanCard(SubscriptionPlanEntity plan, bool isSelected) {
    final isAnnual = plan.isYearly;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedPlanCode = plan.code;
        });
      },
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.surfaceElevated
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected ? AppColors.primary : AppColors.textTertiary,
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
                        plan.name,
                        style: AppTypography.titleMedium.copyWith(
                          color: isSelected
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      if (isAnnual) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusSm),
                          ),
                          child: Text(
                            'SAVE 17%',
                            style: AppTypography.labelSmall.copyWith(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isAnnual
                        ? r'$8.33/month billed annually ($99.99/year)'
                        : r'$9.99 billed monthly',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              plan.formattedPrice,
              style: AppTypography.headlineMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
