import 'package:flutter/material.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/core/theme/app_spacing.dart';
import 'package:hums_mobile/core/theme/app_typography.dart';

class HumsAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;

  const HumsAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.centerTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      titleSpacing: 0,
      automaticallyImplyLeading: false,
      leadingWidth: leading != null ? null : 0,
      leading: leading,
      title: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppTypography.headlineLarge,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              softWrap: false,
            ),
          ),
          if (actions != null)
            ...actions!.map(
                  (a) => Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: a,
              ),
            ),
          if (actions != null) const SizedBox(width: AppSpacing.md),
        ],
      ),
      centerTitle: false,
      backgroundColor: AppColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}