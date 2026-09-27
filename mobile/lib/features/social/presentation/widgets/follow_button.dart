import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/core/theme/app_spacing.dart';
import 'package:hums_mobile/core/theme/app_typography.dart';
import 'package:hums_mobile/features/social/presentation/providers/follow_notifier.dart';

class FollowButton extends ConsumerStatefulWidget {
  final String creatorId;
  final bool initialFollowing;
  final int initialCount;
  final bool compact;
  final ValueChanged<bool>? onFollowChanged;

  const FollowButton({
    super.key,
    required this.creatorId,
    this.initialFollowing = false,
    this.initialCount = 0,
    this.compact = false,
    this.onFollowChanged,
  });

  @override
  ConsumerState<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<FollowButton> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(followNotifierProvider(widget.creatorId).notifier).initialize(
            isFollowing: widget.initialFollowing,
            followersCount: widget.initialCount,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final followState = ref.watch(followNotifierProvider(widget.creatorId));

    final isFollowing = followState.isFollowing;
    final isLoading = followState.isLoading;

    final height = widget.compact ? 34.0 : 42.0;
    final horizontalPadding = widget.compact ? AppSpacing.md : AppSpacing.lg;

    return SizedBox(
      height: height,
      child: ElevatedButton(
        onPressed: isLoading
            ? null
            : () async {
                final newStatus = await ref
                    .read(followNotifierProvider(widget.creatorId).notifier)
                    .toggleFollow();
                widget.onFollowChanged?.call(newStatus);
              },
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isFollowing ? Colors.transparent : AppColors.primary,
          foregroundColor:
              isFollowing ? AppColors.textPrimary : Colors.black,
          elevation: 0,
          side: isFollowing
              ? const BorderSide(color: AppColors.border, width: 1.5)
              : BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          ),
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        ),
        child: isLoading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isFollowing ? AppColors.textPrimary : Colors.black,
                  ),
                ),
              )
            : Text(
                isFollowing ? 'Following' : 'Follow',
                style: AppTypography.labelLarge.copyWith(
                  fontSize: widget.compact ? 13.0 : 14.0,
                  fontWeight: FontWeight.w600,
                  color: isFollowing ? AppColors.textPrimary : Colors.black,
                ),
              ),
      ),
    );
  }
}
