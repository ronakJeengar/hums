import 'package:flutter/material.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/core/theme/app_radii.dart';
import 'package:hums_mobile/core/theme/app_spacing.dart';
import 'package:hums_mobile/core/theme/app_typography.dart';

enum HumsButtonVariant { primary, coral, secondary, outline, danger }

class HumsButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final HumsButtonVariant variant;
  final double? width;
  final double height;
  final double? fontSize;

  const HumsButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.variant = HumsButtonVariant.primary,
    this.width,
    this.height = 48,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color fgColor;
    BorderSide borderSide = BorderSide.none;

    switch (variant) {
      case HumsButtonVariant.primary:
        bgColor = AppColors.whitePill;
        fgColor = AppColors.background;
        break;
      case HumsButtonVariant.coral:
        bgColor = AppColors.primary;
        fgColor = Colors.white;
        break;
      case HumsButtonVariant.secondary:
        bgColor = AppColors.surfaceElevated;
        fgColor = AppColors.textPrimary;
        borderSide = const BorderSide(color: AppColors.borderSubtle, width: 1);
        break;
      case HumsButtonVariant.outline:
        bgColor = Colors.transparent;
        fgColor = AppColors.textPrimary;
        borderSide = const BorderSide(color: AppColors.border, width: 1);
        break;
      case HumsButtonVariant.danger:
        bgColor = AppColors.error;
        fgColor = Colors.white;
        break;
    }

    Widget content = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(fgColor),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: AppSpacing.iconSm + 2, color: fgColor),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(
                label,
                style: AppTypography.labelLarge.copyWith(
                  color: fgColor,
                  fontWeight: FontWeight.w700,
                  fontSize: fontSize ?? 14.0,
                ),
              ),
            ],
          );

    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          disabledBackgroundColor: bgColor.withValues(alpha: 0.5),
          disabledForegroundColor: fgColor.withValues(alpha: 0.5),
          side: borderSide,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          elevation: 0,
        ),
        child: content,
      ),
    );
  }
}
