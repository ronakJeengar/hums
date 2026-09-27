import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/core/theme/app_spacing.dart';
import 'package:hums_mobile/core/theme/app_typography.dart';
import 'package:hums_mobile/features/library/presentation/providers/like_notifier.dart';

/// Reusable universal Like / Favorite button component.
/// Provides immediate optimistic feedback, server synchronization, error rollback,
/// accessibility semantics, and consistent cross-screen state sharing via Riverpod.
class LikeButton extends ConsumerStatefulWidget {
  final String trackId;
  final bool? initialLiked;
  final int? initialCount;
  final String? trackTitle;
  final double size;
  final bool showCount;
  final Color? color;
  final bool autoFetch;

  const LikeButton({
    super.key,
    required this.trackId,
    this.initialLiked,
    this.initialCount,
    this.trackTitle,
    this.size = 22.0,
    this.showCount = false,
    this.color,
    this.autoFetch = false,
  });

  @override
  ConsumerState<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends ConsumerState<LikeButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.8,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );

    // Initialize notifier with known initial state to avoid N+1 network requests
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier = ref.read(likeNotifierProvider(widget.trackId).notifier);
      notifier.initialize(
        initialLiked: widget.initialLiked,
        initialCount: widget.initialCount,
      );
      if (widget.autoFetch) {
        notifier.fetchStatus();
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    await _animController.reverse();
    await _animController.forward();
    if (mounted) {
      ref.read(likeNotifierProvider(widget.trackId).notifier).toggleLike();
    }
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      final millions = count / 1000000;
      return '${millions.toStringAsFixed(millions.truncateToDouble() == millions ? 0 : 1)}M';
    }
    if (count >= 1000) {
      final thousands = count / 1000;
      return '${thousands.toStringAsFixed(thousands.truncateToDouble() == thousands ? 0 : 1)}K';
    }
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    final likeState = ref.watch(likeNotifierProvider(widget.trackId));
    final isLiked = likeState.isLiked;
    final likesCount = likeState.likesCount;
    final trackName = widget.trackTitle ?? 'track';
    final semanticLabel = isLiked ? 'Unlike $trackName' : 'Like $trackName';

    Widget iconWidget = ScaleTransition(
      scale: _scaleAnimation,
      child: Icon(
        isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        size: widget.size,
        color: isLiked
            ? AppColors.error
            : (widget.color ?? AppColors.textSecondary),
      ),
    );

    if (widget.showCount) {
      return Semantics(
        button: true,
        label: '$semanticLabel, ${_formatCount(likesCount)} likes',
        child: InkWell(
          onTap: _handleTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xxs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                iconWidget,
                if (likesCount > 0) ...[
                  const SizedBox(width: AppSpacing.xxs),
                  Text(
                    _formatCount(likesCount),
                    style: AppTypography.labelSmall.copyWith(
                      color: isLiked
                          ? AppColors.error
                          : AppColors.textTertiary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      label: semanticLabel,
      child: IconButton(
        tooltip: semanticLabel,
        icon: iconWidget,
        iconSize: widget.size,
        padding: EdgeInsets.zero,
        constraints: BoxConstraints(
          minWidth: widget.size + 12,
          minHeight: widget.size + 12,
        ),
        splashRadius: widget.size + 4,
        onPressed: _handleTap,
      ),
    );
  }
}
