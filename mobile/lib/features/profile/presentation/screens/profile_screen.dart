import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/core/theme/app_spacing.dart';
import 'package:hums_mobile/core/theme/app_typography.dart';
import 'package:hums_mobile/core/widgets/hums_app_bar.dart';
import 'package:hums_mobile/core/widgets/hums_button.dart';
import 'package:hums_mobile/features/profile/domain/entities/profile_entity.dart';
import 'package:hums_mobile/features/profile/presentation/providers/profile_provider.dart';
import 'package:hums_mobile/features/profile/presentation/states/profile_state.dart';
import 'package:hums_mobile/routing/route_names.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(profileNotifierProvider.notifier).loadProfile();
    });
  }

  Future<void> _pickAndUploadAvatar() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null && mounted) {
        final success = await ref
            .read(profileNotifierProvider.notifier)
            .uploadAvatar(image.path);

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Avatar updated successfully'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _confirmRemoveAvatar() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Remove Avatar', style: AppTypography.titleMedium),
        content: const Text(
          'Are you sure you want to remove your profile picture?',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Remove',
              style: AppTypography.labelLarge.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await ref
          .read(profileNotifierProvider.notifier)
          .removeAvatar();

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Avatar removed'),
            backgroundColor: AppColors.surfaceElevated,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileNotifierProvider);

    ref.listen<ProfileState>(profileNotifierProvider, (previous, next) {
      next.whenOrNull(
        failure: (message, code, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: AppColors.error),
          );
        },
      );
    });

    final profile = state.profile;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: HumsAppBar(
        title: 'Profile',
        actions: [
          if (profile != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
              tooltip: 'Edit Profile',
              onPressed: () => context.push(RouteNames.editProfilePath),
            ),
        ],
      ),
      body: SafeArea(
        child: state.isLoading && profile == null
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : profile == null
            ? _buildErrorState()
            : _buildProfileContent(profile, state),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Could not load profile',
              style: AppTypography.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Please check your connection and try again.',
              style: AppTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            HumsButton(
              label: 'Retry',
              onPressed: () =>
                  ref.read(profileNotifierProvider.notifier).loadProfile(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileContent(ProfileEntity profile, ProfileState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar Section
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  radius: 56,
                  backgroundColor: AppColors.surfaceElevated,
                  backgroundImage: profile.avatarUrl != null
                      ? ResizeImage(
                          NetworkImage(profile.avatarUrl!),
                          width: 224,
                          height: 224,
                        )
                      : null,
                  child: profile.avatarUrl == null
                      ? Text(
                          profile.initials,
                          style: AppTypography.displayMedium.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                if (state.isUploadingAvatar)
                  Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.5),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 3,
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Material(
                    color: AppColors.primary,
                    shape: const CircleBorder(),
                    elevation: 4,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: state.isBusy ? null : _pickAndUploadAvatar,
                      child: const Padding(
                        padding: EdgeInsets.all(AppSpacing.sm),
                        child: Icon(
                          Icons.camera_alt,
                          size: 20,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Remove Avatar Action (if avatar exists)
          if (profile.avatarUrl != null)
            TextButton.icon(
              onPressed: state.isBusy ? null : _confirmRemoveAvatar,
              icon: const Icon(
                Icons.delete_outline,
                size: 18,
                color: AppColors.error,
              ),
              label: Text(
                'Remove Avatar',
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.error,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),

          // Name
          Text(
            profile.name,
            style: AppTypography.headlineLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),

          // Email
          Text(
            profile.email,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),

          // Bio Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'About',
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  profile.bio != null && profile.bio!.isNotEmpty
                      ? profile.bio!
                      : 'No bio added yet. Tell others about yourself and your musical taste.',
                  style: profile.bio != null && profile.bio!.isNotEmpty
                      ? AppTypography.bodyLarge
                      : AppTypography.bodyMedium.copyWith(
                          color: AppColors.textTertiary,
                          fontStyle: FontStyle.italic,
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),

          // Listening History Button
          SizedBox(
            width: double.infinity,
            child: HumsButton(
              label: 'Listening History',
              icon: Icons.history_rounded,
              variant: HumsButtonVariant.secondary,
              onPressed: () => context.push(RouteNames.historyPath),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Edit Profile Button
          SizedBox(
            width: double.infinity,
            child: HumsButton(
              label: 'Edit Profile',
              icon: Icons.edit_outlined,
              onPressed: () => context.push(RouteNames.editProfilePath),
            ),
          ),
        ],
      ),
    );
  }
}
