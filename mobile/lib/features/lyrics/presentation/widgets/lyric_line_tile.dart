import 'package:flutter/material.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/features/lyrics/domain/entities/lyric_line_entity.dart';

class LyricLineTile extends StatelessWidget {
  final LyricLineEntity line;
  final bool isActive;
  final VoidCallback? onTap;

  const LyricLineTile({
    super.key,
    required this.line,
    required this.isActive,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Lyric line: ${line.text}${isActive ? ", currently playing" : ""}',
      hint: 'Double tap to jump playback here',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: AppColors.primary.withValues(alpha: 0.15),
        highlightColor: AppColors.primary.withValues(alpha: 0.08),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            style: TextStyle(
              color: isActive ? AppColors.textPrimary : AppColors.textTertiary,
              fontSize: isActive ? 22 : 17,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              height: 1.45,
              letterSpacing: isActive ? 0.2 : 0.0,
            ),
            child: Text(
              line.text.isEmpty ? '♪' : line.text,
              textAlign: TextAlign.left,
            ),
          ),
        ),
      ),
    );
  }
}
