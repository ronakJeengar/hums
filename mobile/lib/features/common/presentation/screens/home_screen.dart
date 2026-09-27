import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hums_mobile/core/network/api_client.dart';
import 'package:hums_mobile/core/network/api_endpoints.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/core/theme/app_radii.dart';
import 'package:hums_mobile/core/theme/app_spacing.dart';
import 'package:hums_mobile/core/theme/app_typography.dart';
import 'package:hums_mobile/core/widgets/hums_bottom_nav_bar.dart';
import 'package:hums_mobile/core/widgets/hums_button.dart';
import 'package:hums_mobile/core/widgets/hums_chip.dart';
import 'package:hums_mobile/core/widgets/hums_creator_badge_card.dart';
import 'package:hums_mobile/core/widgets/hums_section_header.dart';
import 'package:hums_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:hums_mobile/features/auth/presentation/states/auth_state.dart';
import 'package:hums_mobile/features/notifications/presentation/providers/notification_provider.dart';
import 'package:hums_mobile/features/recommendations/presentation/providers/recommendation_provider.dart';
import 'package:hums_mobile/features/recommendations/presentation/widgets/recommendations_view.dart';
import 'package:hums_mobile/features/social/presentation/providers/following_provider.dart';
import 'package:hums_mobile/routing/route_names.dart';

final systemHealthProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.get<Map<String, dynamic>>(ApiEndpoints.deepHealth);
  return response.data ?? {};
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedCategoryIndex = 0;
  final List<String> _categories = [
    'All',
    'Trending',
    'Acoustic',
    'Indie',
    'Podcasts',
    'Ambient',
  ];

  @override
  Widget build(BuildContext context) {
    final healthAsync = ref.watch(systemHealthProvider);
    final authState = ref.watch(authNotifierProvider);
    final followingState = ref.watch(followingNotifierProvider);
    final userName = authState.user?.name ?? 'Listener';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: Consumer(
          builder: (context, ref, _) {
            final unreadCount = ref.watch(unreadNotificationCountProvider);
            return Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_none_rounded, color: AppColors.textPrimary, size: 24),
                  tooltip: 'Notifications',
                  onPressed: () => context.push(RouteNames.notificationsPath),
                ),
                if (unreadCount > 0)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        title: const Text(
          'hums',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: GestureDetector(
              onTap: () => context.push(RouteNames.profilePath),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.borderSubtle, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: () async {
            ref.invalidate(systemHealthProvider);
            await ref.read(followingNotifierProvider.notifier).refresh();
            await ref.read(recommendationNotifierProvider.notifier).refresh();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Filter Chips Ribbon
                SizedBox(
                  height: 48,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (context, index) => const SizedBox(width: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      return HumsChip(
                        label: _categories[index],
                        isSelected: _selectedCategoryIndex == index,
                        onTap: () {
                          setState(() {
                            _selectedCategoryIndex = index;
                          });
                        },
                      );
                    },
                  ),
                ),

                const SizedBox(height: AppSpacing.sm),

                // Hero Featured Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF382317),
                          Color(0xFF1A1614),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(AppRadii.xl),
                      border: Border.all(color: AppColors.borderSubtle, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                          ),
                          child: const Text(
                            'FEATURED',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const Text(
                          'Acoustic Nights & Warm Echoes',
                          style: AppTypography.headlineLarge,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        const Text(
                          'Handcrafted acoustic sessions and intimate melodies tailored for you.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            HumsButton(
                              label: 'Play Now',
                              icon: Icons.play_arrow_rounded,
                              variant: HumsButtonVariant.coral,
                              height: 42,
                              onPressed: () {
                                context.push(RouteNames.searchPath);
                              },
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            HumsButton(
                              label: 'Explore',
                              variant: HumsButtonVariant.secondary,
                              height: 42,
                              onPressed: () {
                                context.push(RouteNames.searchPath);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                // Quick Access Shortcuts Grid
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Row(
                    children: [
                      _buildQuickActionCard(
                        context,
                        icon: Icons.favorite_rounded,
                        label: 'Liked Songs',
                        color: AppColors.primary,
                        onTap: () => context.push(RouteNames.likedSongsPath),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _buildQuickActionCard(
                        context,
                        icon: Icons.collections_bookmark_rounded,
                        label: 'Library',
                        color: AppColors.accentMint,
                        onTap: () => context.push(RouteNames.libraryPath),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _buildQuickActionCard(
                        context,
                        icon: Icons.download_done_rounded,
                        label: 'Downloads',
                        color: AppColors.accentBlue,
                        onTap: () => context.push(RouteNames.downloadsPath),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _buildQuickActionCard(
                        context,
                        icon: Icons.history_rounded,
                        label: 'History',
                        color: AppColors.accentPurple,
                        onTap: () => context.push(RouteNames.historyPath),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                // "From creators you follow" Carousel
                HumsSectionHeader(
                  title: 'From creators you follow',
                  actionLabel: 'View all',
                  onActionTap: () => context.push(RouteNames.followingPath),
                ),
                const SizedBox(height: AppSpacing.xs),
                _buildCreatorsSection(context, followingState),

                const SizedBox(height: AppSpacing.xl),

                // Recommendations Section
                const RecommendationsView(),

                const SizedBox(height: AppSpacing.xl),

                // Creator Studio Banner
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                      border: Border.all(color: AppColors.borderSubtle, width: 1),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadii.md),
                          ),
                          child: const Icon(Icons.mic_none_rounded, color: AppColors.primary, size: 24),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Creator Studio',
                                style: AppTypography.titleMedium,
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Upload audio tracks and share with listeners.',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        HumsButton(
                          label: 'Upload',
                          variant: HumsButtonVariant.primary,
                          height: 38,
                          onPressed: () => context.push(RouteNames.uploadAudioPath),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                // System Health Status Card (Discreet)
                _buildSystemHealthCard(healthAsync),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const HumsBottomNavBar(currentIndex: 0),
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2, horizontal: AppSpacing.xs),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: AppColors.borderSubtle, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreatorsSection(BuildContext context, FollowingState followingState) {
    if (followingState.isLoading) {
      return const SizedBox(
        height: 180,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
        ),
      );
    }

    if (followingState.creators.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            children: [
              const Icon(Icons.people_outline_rounded, color: AppColors.textTertiary, size: 32),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Discover Artists', style: AppTypography.titleMedium),
                    SizedBox(height: 2),
                    Text(
                      'Follow creators to see their latest releases here.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              HumsButton(
                label: 'Find',
                variant: HumsButtonVariant.secondary,
                height: 36,
                onPressed: () => context.push(RouteNames.searchPath),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 215,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        scrollDirection: Axis.horizontal,
        itemCount: followingState.creators.length,
        itemBuilder: (context, index) {
          final creator = followingState.creators[index];
          return HumsCreatorBadgeCard(
            title: creator.name,
            creatorName: creator.bio ?? 'Artist',
            artworkUrl: creator.avatarUrl,
            creatorAvatarUrl: creator.avatarUrl,
            categoryTag: 'CREATOR',
            onTap: () {
              context.push(RouteNames.creatorProfilePathFor(creator.id));
            },
          );
        },
      ),
    );
  }

  Widget _buildSystemHealthCard(AsyncValue<Map<String, dynamic>> healthAsync) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: healthAsync.when(
        data: (data) {
          final services = data['data']?['services'] as Map<String, dynamic>?;
          final dbStatus = services?['database'] == 'connected';
          final redisStatus = services?['redis'] == 'connected';

          return Container(
            padding: const EdgeInsets.all(AppSpacing.sm + 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: dbStatus && redisStatus ? AppColors.success : AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      dbStatus && redisStatus ? 'Services Operational' : 'Degraded Services',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                Text(
                  'Postgres & Redis',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (err, stack) => const SizedBox.shrink(),
      ),
    );
  }
}
