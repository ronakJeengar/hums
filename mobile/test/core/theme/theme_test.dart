import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/core/theme/app_theme.dart';
import 'package:hums_mobile/core/theme/app_typography.dart';

void main() {
  group('Theme & Design System Tests', () {
    test('Dark theme enforces dark brightness and correct background', () {
      final theme = AppTheme.darkTheme;
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, AppColors.background);
      expect(theme.colorScheme.primary, AppColors.primary);
      expect(theme.colorScheme.surface, AppColors.surface);
    });

    test('Typography tokens define consistent font sizes and colors', () {
      expect(AppTypography.displayLarge.fontSize, 32.0);
      expect(AppTypography.displayLarge.color, AppColors.textPrimary);
      expect(AppTypography.bodyMedium.fontSize, 14.0);
      expect(AppTypography.bodyMedium.color, AppColors.textSecondary);
    });
  });
}
