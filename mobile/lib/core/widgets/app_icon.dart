import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/core/theme/app_icons.dart';

class AppIcon extends StatelessWidget {
  final String icon;
  final double size;
  final Color? color;
  final String? semanticLabel;

  const AppIcon({
    super.key,
    required this.icon,
    this.size = AppIconSizes.md,
    this.color,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.textPrimary;

    return Semantics(
      label: semanticLabel,
      image: true,
      child: SvgPicture.asset(
        icon,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(effectiveColor, BlendMode.srcIn),
      ),
    );
  }
}
