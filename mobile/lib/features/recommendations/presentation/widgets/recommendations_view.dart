import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/core/theme/app_spacing.dart';
import 'package:hums_mobile/core/theme/app_typography.dart';
import 'package:hums_mobile/core/widgets/hums_button.dart';
import 'package:hums_mobile/features/recommendations/presentation/providers/recommendation_provider.dart';
import 'package:hums_mobile/features/recommendations/presentation/widgets/recommendation_section_widget.dart';

class RecommendationsView extends ConsumerStatefulWidget {
  const RecommendationsView({super.key});

  @override
  ConsumerState<RecommendationsView> createState() =>
      _RecommendationsViewState();
}

class _RecommendationsViewState extends ConsumerState<RecommendationsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(recommendationNotifierProvider.notifier).loadRecommendations();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recommendationNotifierProvider);

    if (state.isLoading && state.sections.isEmpty) {
      return _buildLoadingSkeleton();
    }

    if (state.hasError && state.sections.isEmpty) {
      return _buildErrorState(state.errorMessage ?? 'Failed to load recommendations');
    }

    if (state.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final section in state.sections)
          if (section.hasItems)
            RecommendationSectionWidget(
              key: ValueKey('rec_section_${section.id}'),
              section: section,
            ),
      ],
    );
  }

  Widget _buildLoadingSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Container(
            width: 180,
            height: 22,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 215,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            scrollDirection: Axis.horizontal,
            itemCount: 3,
            itemBuilder: (context, index) {
              return Container(
                width: 150,
                margin: const EdgeInsets.only(right: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 120,
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(AppSpacing.radiusMd),
                          topRight: Radius.circular(AppSpacing.radiusMd),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 100,
                            height: 14,
                            color: AppColors.surfaceElevated,
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 70,
                            height: 12,
                            color: AppColors.surfaceElevated,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Widget _buildErrorState(String message) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.warning,
            size: AppSpacing.iconMd,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recommendations Unavailable',
                  style: AppTypography.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          HumsButton(
            label: 'Retry',
            variant: HumsButtonVariant.secondary,
            onPressed: () {
              ref
                  .read(recommendationNotifierProvider.notifier)
                  .loadRecommendations(refresh: true);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.primary,
              size: AppSpacing.iconMd,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No Recommendations Yet',
                  style: AppTypography.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  'Discover sounds by exploring playlists and uploading your favorite tracks.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
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
