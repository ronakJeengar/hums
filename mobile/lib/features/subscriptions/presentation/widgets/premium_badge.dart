import 'package:flutter/material.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/core/theme/app_spacing.dart';
import 'package:hums_mobile/core/theme/app_typography.dart';

enum PremiumBadgeSize { small, medium, large }

class PremiumBadge extends StatelessWidget {
  final PremiumBadgeSize size;
  final String? label;

  const PremiumBadge({
    super.key,
    this.size = PremiumBadgeSize.small,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final text = label ?? 'PREMIUM';
    double horizontalPadding;
    double verticalPadding;
    double iconSize;
    TextStyle textStyle;

    switch (size) {
      case PremiumBadgeSize.small:
        horizontalPadding = AppSpacing.xs;
        verticalPadding = 2.0;
        iconSize = 10.0;
        textStyle = AppTypography.labelSmall.copyWith(
          color: Colors.black,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
          fontSize: 9,
        );
        break;
      case PremiumBadgeSize.medium:
        horizontalPadding = AppSpacing.sm;
        verticalPadding = AppSpacing.xs;
        iconSize = 12.0;
        textStyle = AppTypography.labelSmall.copyWith(
          color: Colors.black,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
          fontSize: 11,
        );
        break;
      case PremiumBadgeSize.large:
        horizontalPadding = AppSpacing.md;
        verticalPadding = AppSpacing.sm;
        iconSize = 16.0;
        textStyle = AppTypography.labelLarge.copyWith(
          color: Colors.black,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        );
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryLight, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.workspace_premium_rounded,
            size: iconSize,
            color: Colors.black,
          ),
          const SizedBox(width: 3),
          Text(text, style: textStyle),
        ],
      ),
    );
  }
}
