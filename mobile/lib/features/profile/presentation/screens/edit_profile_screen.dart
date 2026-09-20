import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/core/theme/app_spacing.dart';
import 'package:hums_mobile/core/theme/app_typography.dart';
import 'package:hums_mobile/core/widgets/hums_app_bar.dart';
import 'package:hums_mobile/core/widgets/hums_button.dart';
import 'package:hums_mobile/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:hums_mobile/features/profile/presentation/providers/profile_provider.dart';
import 'package:hums_mobile/features/profile/presentation/states/profile_state.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _bioController;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileNotifierProvider).profile;
    _nameController = TextEditingController(text: profile?.name ?? '');
    _emailController = TextEditingController(text: profile?.email ?? '');
    _bioController = TextEditingController(text: profile?.bio ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final bio = _bioController.text.trim();

    final success = await ref.read(profileNotifierProvider.notifier).updateProfile(
          name: name,
          email: email,
          bio: bio,
        );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileNotifierProvider);
    final isUpdating = state.isUpdating || state.isLoading;

    ref.listen<ProfileState>(profileNotifierProvider, (previous, next) {
      next.whenOrNull(
        failure: (message, code, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: AppColors.error,
            ),
          );
        },
      );
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const HumsAppBar(
        title: 'Edit Profile',
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Update your profile information below.',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Name field
                AuthTextField(
                  label: 'Name',
                  hintText: 'Your display name',
                  controller: _nameController,
                  prefixIcon: Icons.person_outline,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your name';
                    }
                    if (value.trim().length < 2) {
                      return 'Name must be at least 2 characters';
                    }
                    if (value.trim().length > 100) {
                      return 'Name must be less than 100 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                // Email field
                AuthTextField(
                  label: 'Email',
                  hintText: 'your.email@example.com',
                  controller: _emailController,
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email';
                    }
                    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                    if (!emailRegex.hasMatch(value.trim())) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                // Bio field
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Bio', style: AppTypography.labelLarge),
                    const SizedBox(height: AppSpacing.xs),
                    TextFormField(
                      controller: _bioController,
                      maxLines: 4,
                      maxLength: 500,
                      style: AppTypography.bodyLarge,
                      decoration: InputDecoration(
                        hintText: 'Tell us a bit about your musical taste or audio work...',
                        hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary),
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                        counterStyle: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary),
                      ),
                      validator: (value) {
                        if (value != null && value.trim().length > 500) {
                          return 'Bio must not exceed 500 characters';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: HumsButton(
                    label: 'Save Changes',
                    isLoading: isUpdating,
                    onPressed: isUpdating ? null : _handleSubmit,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
