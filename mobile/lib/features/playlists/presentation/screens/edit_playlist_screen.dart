import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/core/theme/app_icons.dart';
import 'package:hums_mobile/core/theme/app_spacing.dart';
import 'package:hums_mobile/core/theme/app_typography.dart';
import 'package:hums_mobile/core/widgets/app_icon.dart';
import 'package:hums_mobile/core/widgets/hums_app_bar.dart';
import 'package:hums_mobile/features/playlists/domain/entities/playlist_entity.dart';
import 'package:hums_mobile/features/playlists/presentation/providers/playlist_provider.dart';

class EditPlaylistScreen extends ConsumerStatefulWidget {
  final String playlistId;

  const EditPlaylistScreen({super.key, required this.playlistId});

  @override
  ConsumerState<EditPlaylistScreen> createState() => _EditPlaylistScreenState();
}

class _EditPlaylistScreenState extends ConsumerState<EditPlaylistScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  final _picker = ImagePicker();
  String? _newImagePath;
  bool _removeExistingCover = false;
  bool _isPublic = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(playlistDetailNotifierProvider(widget.playlistId).notifier)
          .loadDetails();
    });
  }

  void _initializeFields(PlaylistEntity playlist) {
    if (!_isInitialized) {
      _nameController.text = playlist.name;
      _descriptionController.text = playlist.description ?? '';
      _isPublic = playlist.isPublic;
      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickCoverImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        setState(() {
          _newImagePath = image.path;
          _removeExistingCover = false;
        });
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();

    final formNotifier = ref.read(playlistFormNotifierProvider.notifier);
    final detailNotifier =
        ref.read(playlistDetailNotifierProvider(widget.playlistId).notifier);

    // If user asked to remove existing cover and didn't select a new one
    if (_removeExistingCover && _newImagePath == null) {
      await detailNotifier.removeCover();
    }

    final updated = await formNotifier.updatePlaylist(
      widget.playlistId,
      name: name,
      description: description.isNotEmpty ? description : null,
      isPublic: _isPublic,
      coverFilePath: _newImagePath,
    );

    if (updated != null && mounted) {
      ref.read(playlistListNotifierProvider.notifier).addOrUpdatePlaylist(updated);
      await detailNotifier.loadDetails();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Playlist updated successfully'),
            backgroundColor: AppColors.surfaceElevated,
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailState =
        ref.watch(playlistDetailNotifierProvider(widget.playlistId));
    final formState = ref.watch(playlistFormNotifierProvider);

    if (detailState.isLoading && detailState.detail == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: const HumsAppBar(title: 'Edit Playlist'),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final playlist = detailState.detail?.playlist;
    if (playlist == null && !detailState.isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: const HumsAppBar(title: 'Edit Playlist'),
        body: Center(
          child: Text(
            detailState.errorMessage ?? 'Playlist not found',
            style: AppTypography.bodyLarge.copyWith(color: AppColors.error),
          ),
        ),
      );
    }

    if (playlist != null) {
      _initializeFields(playlist);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: HumsAppBar(
        title: 'Edit Playlist',
        leading: IconButton(
          icon: const AppIcon(
            icon: AppIcons.back,
            size: AppIconSizes.md,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cover Artwork
                Center(
                  child: GestureDetector(
                    onTap: formState.isSubmitting ? null : _pickCoverImage,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        child: _buildCoverWidget(playlist!),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: formState.isSubmitting ? null : _pickCoverImage,
                        child: Text(
                          'Change Cover',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.primary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (playlist.coverImageUrl != null || _newImagePath != null) ...[
                        const SizedBox(width: AppSpacing.md),
                        TextButton(
                          onPressed: formState.isSubmitting
                              ? null
                              : () {
                                  setState(() {
                                    _newImagePath = null;
                                    _removeExistingCover = true;
                                  });
                                },
                          child: Text(
                            'Remove Cover',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.error,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Name Field
                Text(
                  'Playlist Name *',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                TextFormField(
                  controller: _nameController,
                  enabled: !formState.isSubmitting,
                  style: AppTypography.bodyLarge,
                  decoration: InputDecoration(
                    hintText: 'Playlist Name',
                    hintStyle: AppTypography.bodyLarge.copyWith(
                      color: AppColors.textTertiary,
                    ),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter a playlist name';
                    }
                    if (val.trim().length > 100) {
                      return 'Name must be 100 characters or fewer';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                // Description Field
                Text(
                  'Description (optional)',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                TextFormField(
                  controller: _descriptionController,
                  enabled: !formState.isSubmitting,
                  maxLines: 3,
                  style: AppTypography.bodyLarge,
                  decoration: InputDecoration(
                    hintText: 'Add an optional description...',
                    hintStyle: AppTypography.bodyLarge.copyWith(
                      color: AppColors.textTertiary,
                    ),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                  validator: (val) {
                    if (val != null && val.trim().length > 500) {
                      return 'Description must be 500 characters or fewer';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                // Error Banner
                if (formState.hasError) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      border: Border.all(color: AppColors.error),
                    ),
                    child: Text(
                      formState.errorMessage!,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],

                // Save Button
                ElevatedButton(
                  onPressed: formState.isSubmitting ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                  ),
                  child: formState.isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : Text(
                          'Save Changes',
                          style: AppTypography.labelLarge.copyWith(
                            color: Colors.black,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoverWidget(PlaylistEntity playlist) {
    if (_newImagePath != null) {
      return Image.file(
        File(_newImagePath!),
        width: 140,
        height: 140,
        fit: BoxFit.cover,
      );
    }

    if (playlist.coverImageUrl != null && !_removeExistingCover) {
      return Image.network(
        playlist.coverImageUrl!,
        width: 140,
        height: 140,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    }

    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const AppIcon(
          icon: AppIcons.playlist,
          size: AppIconSizes.xl,
          color: AppColors.textSecondary,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Add Cover',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
