import 'package:flutter/material.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/core/theme/app_radii.dart';

class HumsArtwork extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final bool hasShadow;
  final IconData placeholderIcon;

  const HumsArtwork({
    super.key,
    this.imageUrl,
    this.size = 48.0,
    this.width,
    this.height,
    this.borderRadius,
    this.hasShadow = false,
    this.placeholderIcon = Icons.music_note_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveWidth = width ?? size;
    final effectiveHeight = height ?? size;
    final effectiveRadius = borderRadius ?? AppRadii.bSm;

    Widget imageWidget;
    if (imageUrl != null && imageUrl!.trim().isNotEmpty) {
      imageWidget = Image.network(
        imageUrl!,
        width: effectiveWidth,
        height: effectiveHeight,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(
          effectiveWidth,
          effectiveHeight,
        ),
      );
    } else {
      imageWidget = _buildPlaceholder(effectiveWidth, effectiveHeight);
    }

    return Container(
      width: effectiveWidth,
      height: effectiveHeight,
      decoration: BoxDecoration(
        borderRadius: effectiveRadius,
        boxShadow: hasShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: effectiveRadius,
        child: imageWidget,
      ),
    );
  }

  Widget _buildPlaceholder(double w, double h) {
    return Container(
      width: w,
      height: h,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceHighlight,
            AppColors.surface,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          placeholderIcon,
          size: (w < h ? w : h) * 0.45,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }
}
