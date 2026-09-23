import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/core/theme/app_spacing.dart';
import 'package:hums_mobile/features/notifications/domain/entities/notification_item.dart';
import 'package:hums_mobile/features/notifications/presentation/providers/notification_provider.dart';
import 'package:hums_mobile/features/notifications/presentation/states/notification_state.dart';
import 'package:hums_mobile/features/notifications/presentation/widgets/notification_preferences_modal.dart';
import 'package:hums_mobile/features/notifications/presentation/widgets/notification_tile.dart';

enum NotificationFilter { all, unread }

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  NotificationFilter _selectedFilter = NotificationFilter.all;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(notificationInboxNotifierProvider.notifier).loadNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationInboxNotifierProvider);
    final notifier = ref.read(notificationInboxNotifierProvider.notifier);

    final displayedNotifications = _selectedFilter == NotificationFilter.unread
        ? state.notifications.where((n) => !n.isRead).toList()
        : state.notifications;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Row(
          children: [
            const Text(
              'Notifications',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
            if (state.unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${state.unreadCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (state.unreadCount > 0)
            TextButton(
              onPressed: () => notifier.markAllAsRead(),
              child: const Text(
                'Read all',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: AppColors.textPrimary),
            tooltip: 'Notification Preferences',
            onPressed: () => NotificationPreferencesModal.show(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs (All / Unread)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'All',
                  isSelected: _selectedFilter == NotificationFilter.all,
                  onSelected: () => setState(() => _selectedFilter = NotificationFilter.all),
                ),
                const SizedBox(width: AppSpacing.sm),
                _buildFilterChip(
                  label: 'Unread (${state.unreadCount})',
                  isSelected: _selectedFilter == NotificationFilter.unread,
                  onSelected: () => setState(() => _selectedFilter = NotificationFilter.unread),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // Main Content
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              onRefresh: () => notifier.refresh(),
              child: _buildBody(state, displayedNotifications),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    return GestureDetector(
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    NotificationInboxState state,
    List<NotificationItemEntity> items,
  ) {
    if (state.isLoading && !state.isRefreshing) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (state.hasError && state.notifications.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: AppColors.error,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  state.errorMessage ?? 'Failed to load notifications',
                  style: const TextStyle(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  onPressed: () {
                    ref.read(notificationInboxNotifierProvider.notifier).loadNotifications();
                  },
                  child: const Text('Try Again', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (items.isEmpty) {
      final isUnreadOnly = _selectedFilter == NotificationFilter.unread;
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isUnreadOnly
                      ? Icons.mark_email_read_rounded
                      : Icons.notifications_none_rounded,
                  size: 56,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  isUnreadOnly
                      ? 'No unread notifications'
                      : 'No notifications yet',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isUnreadOnly
                      ? 'You are completely caught up!'
                      : 'We will notify you about your uploads, new releases, and updates.',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final notification = items[index];
        return NotificationTile(
          notification: notification,
          onTap: () {
            // 1. Mark as read
            if (!notification.isRead) {
              ref
                  .read(notificationInboxNotifierProvider.notifier)
                  .markAsRead(notification.id);
            }

            // 2. Navigate if deep link exists
            final route = notification.deepLinkRoute;
            if (route != null) {
              context.push(route);
            }
          },
        );
      },
    );
  }
}
