import 'package:flutter/material.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/core/theme/app_spacing.dart';
import 'package:hums_mobile/core/theme/app_typography.dart';

class SearchSuggestionsList extends StatelessWidget {
  final List<String> suggestions;
  final ValueChanged<String> onSelect;

  const SearchSuggestionsList({
    super.key,
    required this.suggestions,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Text(
            'Suggestions',
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: suggestions.length,
          separatorBuilder: (context, index) => const Divider(
            height: 1,
            color: AppColors.border,
            indent: AppSpacing.md,
          ),
          itemBuilder: (context, index) {
            final suggestion = suggestions[index];
            return ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xxs,
              ),
              leading: const Icon(
                Icons.search_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              title: Text(
                suggestion,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              trailing: const Icon(
                Icons.north_west_rounded,
                color: AppColors.textTertiary,
                size: 16,
              ),
              onTap: () => onSelect(suggestion),
            );
          },
        ),
      ],
    );
  }
}
