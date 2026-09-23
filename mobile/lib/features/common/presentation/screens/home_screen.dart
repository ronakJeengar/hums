import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hums_mobile/core/network/api_client.dart';
import 'package:hums_mobile/core/network/api_endpoints.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/core/theme/app_spacing.dart';
import 'package:hums_mobile/core/theme/app_typography.dart';
import 'package:hums_mobile/core/theme/app_icons.dart';
import 'package:hums_mobile/core/widgets/app_icon.dart';
import 'package:hums_mobile/core/widgets/hums_app_bar.dart';
import 'package:hums_mobile/core/widgets/hums_button.dart';

import 'package:go_router/go_router.dart';
import 'package:hums_mobile/routing/route_names.dart';

import 'package:hums_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:hums_mobile/features/auth/presentation/states/auth_state.dart';
import 'package:hums_mobile/features/audio_player/presentation/widgets/mini_player.dart';
import 'package:hums_mobile/features/notifications/presentation/providers/notification_provider.dart';

// AsyncNotifier or FutureProvider for system health check
final systemHealthProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.get<Map<String, dynamic>>(ApiEndpoints.deepHealth);
  return response.data ?? {};
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthAsync = ref.watch(systemHealthProvider);
    final authState = ref.watch(authNotifierProvider);
    final userName = authState.user?.name;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: HumsAppBar(
        title: 'Hums',
        centerTitle: false,
        actions: [
          Consumer(
            builder: (context, ref, _) {
              final unreadCount = ref.watch(unreadNotificationCountProvider);
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, color: AppColors.textPrimary),
                    tooltip: 'Notifications',
                    onPressed: () {
                      context.push(RouteNames.notificationsPath);
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const AppIcon(
              icon: AppIcons.playlist,
              size: AppIconSizes.md,
              color: AppColors.textPrimary,
            ),
            tooltip: 'Playlists',
            onPressed: () {
              context.push(RouteNames.playlistsPath);
            },
          ),
          IconButton(
            icon: const Icon(Icons.library_music_outlined, color: AppColors.textPrimary),
            tooltip: 'My Tracks',
            onPressed: () {
              context.push(RouteNames.userTracksPath);
            },
          ),
          IconButton(
            icon: const Icon(Icons.cloud_upload_outlined, color: AppColors.primary),
            tooltip: 'Upload Audio',
            onPressed: () {
              context.push(RouteNames.uploadAudioPath);
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_outline_rounded, color: AppColors.textPrimary),
            tooltip: 'Profile',
            onPressed: () {
              context.push(RouteNames.profilePath);
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.textSecondary),
            tooltip: 'Log Out',
            onPressed: () {
              ref.read(authNotifierProvider.notifier).logout();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Welcome Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.surfaceElevated,
                      AppColors.surface,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.graphic_eq_rounded,
                            color: AppColors.primary,
                            size: AppSpacing.iconMd,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Foundation Active',
                          style: AppTypography.labelLarge.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      userName != null ? 'Welcome, $userName' : 'Welcome to Hums',
                      style: AppTypography.displayMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Text(
                      'Your standalone, high-fidelity audio and podcast streaming experience.',
                      style: AppTypography.bodyMedium,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Creator Hub Quick Action Card
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Creator Studio',
                            style: AppTypography.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            'Upload audio files and manage your tracks.',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    HumsButton(
                      label: 'My Tracks',
                      variant: HumsButtonVariant.secondary,
                      onPressed: () {
                        context.push(RouteNames.userTracksPath);
                      },
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    HumsButton(
                      label: 'Upload',
                      variant: HumsButtonVariant.primary,
                      onPressed: () {
                        context.push(RouteNames.uploadAudioPath);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Playlists Quick Action Card
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Playlists',
                            style: AppTypography.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            'Organize and stream your custom track queues.',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    HumsButton(
                      label: 'View Playlists',
                      variant: HumsButtonVariant.primary,
                      onPressed: () {
                        context.push(RouteNames.playlistsPath);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // Backend Health Check Live Card
              const Text(
                'System Status',
                style: AppTypography.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.sm),

              healthAsync.when(
                data: (data) {
                  final services = data['data']?['services'] as Map<String, dynamic>?;
                  final dbStatus = services?['database'] ?? 'unknown';
                  final redisStatus = services?['redis'] ?? 'unknown';
                  final env = data['data']?['environment'] ?? 'development';

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Backend API: Connected',
                                style: AppTypography.titleMedium.copyWith(
                                  color: AppColors.success,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: AppSpacing.xxs,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                ),
                                child: Text(
                                  env.toString().toUpperCase(),
                                  style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.success,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          const Divider(),
                          const SizedBox(height: AppSpacing.sm),
                          _buildServiceRow(
                            'PostgreSQL Database',
                            dbStatus == 'connected',
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          _buildServiceRow(
                            'Redis Cache & Broker',
                            redisStatus == 'connected',
                          ),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const Card(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: AppSpacing.md),
                        Text('Checking backend health...', style: AppTypography.bodyMedium),
                      ],
                    ),
                  ),
                ),
                error: (err, stack) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.cloud_off, color: AppColors.error),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'Backend Connection Pending',
                              style: AppTypography.titleMedium.copyWith(
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Ensure backend server is running on configured API host.',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        HumsButton(
                          label: 'Retry Connection',
                          variant: HumsButtonVariant.outline,
                          onPressed: () => ref.invalidate(systemHealthProvider),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // Upcoming Core Features Preview
              const Text(
                'Next Steps Roadmap',
                style: AppTypography.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.sm),

              _buildRoadmapCard(
                icon: Icons.lock_outline_rounded,
                title: 'Authentication & Profiles',
                subtitle: 'Secure JWT sign up, sign in, and user profile management.',
                badgeText: 'Next Feature',
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildRoadmapCard(
                icon: Icons.cloud_upload_outlined,
                title: 'Audio Upload & Transcoding',
                subtitle: 'S3 upload, Celery FFmpeg transcoding, and waveform generation.',
                badgeText: 'Planned',
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildRoadmapCard(
                icon: Icons.play_circle_outline_rounded,
                title: 'Audio Streaming Player',
                subtitle: 'Pristine HLS playback with waveform scrubbing and persistent mini-player.',
                badgeText: 'Planned',
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }

  Widget _buildServiceRow(String name, bool isOnline) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(name, style: AppTypography.bodyMedium),
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOnline ? AppColors.success : AppColors.error,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              isOnline ? 'Online' : 'Degraded',
              style: AppTypography.labelSmall.copyWith(
                color: isOnline ? AppColors.success : AppColors.error,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRoadmapCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String badgeText,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Icon(icon, color: AppColors.primary, size: AppSpacing.iconMd),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(title, style: AppTypography.titleMedium),
                      Text(
                        badgeText,
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
