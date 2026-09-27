import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/core/theme/app_radii.dart';
import 'package:hums_mobile/features/audio_player/presentation/widgets/mini_player.dart';
import 'package:hums_mobile/routing/route_names.dart';

class HumsBottomNavBar extends StatelessWidget {
  final int currentIndex;

  const HumsBottomNavBar({
    super.key,
    required this.currentIndex,
  });

  void _onItemTapped(BuildContext context, int index) {
    if (index == currentIndex) return;

    switch (index) {
      case 0:
        context.go(RouteNames.homePath);
        break;
      case 1:
        context.push(RouteNames.searchPath);
        break;
      case 2:
        context.push(RouteNames.libraryPath);
        break;
      case 3:
        context.push(RouteNames.playlistsPath);
        break;
      case 4:
        context.push(RouteNames.profilePath);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Floating MiniPlayer docked above navigation bar
        const MiniPlayer(),
        Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            border: Border(
              top: BorderSide(color: AppColors.borderSubtle, width: 1),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 60,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(context, 0, Icons.home_rounded, 'Home'),
                  _buildNavItem(context, 1, Icons.search_rounded, 'Search'),
                  _buildNavItem(context, 2, Icons.collections_bookmark_rounded, 'Library'),
                  _buildNavItem(context, 3, Icons.queue_music_rounded, 'Playlists'),
                  _buildNavItem(context, 4, Icons.person_rounded, 'Profile'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavItem(BuildContext context, int index, IconData icon, String label) {
    final isSelected = index == currentIndex;
    final color = isSelected ? AppColors.primary : AppColors.textTertiary;

    return Expanded(
      child: InkWell(
        onTap: () => _onItemTapped(context, index),
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
