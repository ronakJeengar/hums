import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/core/theme/app_spacing.dart';
import 'package:hums_mobile/core/theme/app_typography.dart';
import 'package:hums_mobile/core/widgets/hums_app_bar.dart';
import 'package:hums_mobile/core/widgets/hums_button.dart';
import 'package:hums_mobile/features/audio/presentation/providers/audio_upload_provider.dart';
import 'package:hums_mobile/features/audio/presentation/states/audio_upload_state.dart';
import 'package:hums_mobile/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:hums_mobile/routing/route_names.dart';

class UploadAudioScreen extends ConsumerStatefulWidget {
  const UploadAudioScreen({super.key});

  @override
  ConsumerState<UploadAudioScreen> createState() => _UploadAudioScreenState();
}

class _UploadAudioScreenState extends ConsumerState<UploadAudioScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _artistController = TextEditingController();
  final _albumController = TextEditingController();
  final _genreController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _albumController.dispose();
    _genreController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _onUploadPressed() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref
        .read(audioUploadNotifierProvider.notifier)
        .uploadAudio(
          title: _titleController.text,
          artistName: _artistController.text.isNotEmpty
              ? _artistController.text
              : null,
          albumName: _albumController.text.isNotEmpty
              ? _albumController.text
              : null,
          genre:
              _genreController.text.isNotEmpty ? _genreController.text : null,
          description: _descriptionController.text.isNotEmpty
              ? _descriptionController.text
              : null,
        );

    if (success && mounted) {
      ref.invalidate(userTracksProvider);
    }
  }

  void _resetForm() {
    _titleController.clear();
    _artistController.clear();
    _albumController.clear();
    _genreController.clear();
    _descriptionController.clear();
    ref.read(audioUploadNotifierProvider.notifier).reset();
  }

  @override
  Widget build(BuildContext context) {
    final uploadState = ref.watch(audioUploadNotifierProvider);
    final notifier = ref.read(audioUploadNotifierProvider.notifier);

    final canUpload = !uploadState.isUploading &&
        uploadState.selectedFilePath != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: HumsAppBar(
        title: 'Upload Audio',
        actions: [
          IconButton(
            icon: const Icon(Icons.library_music_outlined,
                color: AppColors.textPrimary),
            tooltip: 'My Uploads',
            onPressed: () {
              context.push(RouteNames.userTracksPath);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Success state view
              if (uploadState.isUploaded) ...[
                _buildSuccessCard(uploadState),
                const SizedBox(height: AppSpacing.lg),
                HumsButton(
                  label: 'Upload Another Track',
                  variant: HumsButtonVariant.primary,
                  onPressed: _resetForm,
                ),
                const SizedBox(height: AppSpacing.sm),
                HumsButton(
                  label: 'View All Tracks',
                  variant: HumsButtonVariant.outline,
                  onPressed: () {
                    context.push(RouteNames.userTracksPath);
                  },
                ),
              ] else ...[
                // File Selection Card
                _buildFilePickerSection(uploadState, notifier),
                const SizedBox(height: AppSpacing.lg),

                // Error Banner
                if (uploadState.isFailure) ...[
                  _buildErrorBanner(uploadState.errorMessage ?? 'Upload failed'),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Upload Progress Bar
                if (uploadState.isUploading) ...[
                  _buildProgressSection(uploadState),
                  const SizedBox(height: AppSpacing.lg),
                ],

                // Metadata Form
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Track Metadata',
                        style: AppTypography.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AuthTextField(
                        controller: _titleController,
                        label: 'Title *',
                        hintText: 'Enter track title',
                        prefixIcon: Icons.music_note_rounded,
                        enabled: !uploadState.isUploading,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Track title is required';
                          }
                          if (value.trim().length > 255) {
                            return 'Title cannot exceed 255 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AuthTextField(
                        controller: _artistController,
                        label: 'Artist Name',
                        hintText: 'e.g. Acoustic Ensemble',
                        prefixIcon: Icons.person_outline_rounded,
                        enabled: !uploadState.isUploading,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AuthTextField(
                        controller: _albumController,
                        label: 'Album Name',
                        hintText: 'e.g. Midnight Sessions Vol. 1',
                        prefixIcon: Icons.album_outlined,
                        enabled: !uploadState.isUploading,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AuthTextField(
                        controller: _genreController,
                        label: 'Genre',
                        hintText: 'e.g. Ambient, Classical, Acoustic, Podcast',
                        prefixIcon: Icons.category_outlined,
                        enabled: !uploadState.isUploading,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AuthTextField(
                        controller: _descriptionController,
                        label: 'Description',
                        hintText: 'Optional notes, credits, or show notes',
                        prefixIcon: Icons.notes_rounded,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        enabled: !uploadState.isUploading,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      HumsButton(
                        label: uploadState.isUploading
                            ? 'Uploading Track...'
                            : 'Upload Track',
                        isLoading: uploadState.isUploading,
                        onPressed: canUpload ? _onUploadPressed : null,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilePickerSection(
    AudioUploadState state,
    AudioUploadNotifier notifier,
  ) {
    final fileName = state.selectedFileName;
    final fileSize = state.selectedFileSize;

    if (fileName != null && fileSize != null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: const Icon(
                Icons.audio_file_rounded,
                color: AppColors.primary,
                size: AppSpacing.iconLg,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: AppTypography.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    _formatFileSize(fileSize),
                    style: AppTypography.labelSmall,
                  ),
                ],
              ),
            ),
            if (!state.isUploading)
              IconButton(
                icon: const Icon(Icons.swap_horiz_rounded,
                    color: AppColors.textSecondary),
                tooltip: 'Change File',
                onPressed: () => notifier.pickFile(),
              ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: state.isUploading ? null : () => notifier.pickFile(),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.xl,
          horizontal: AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: AppColors.border,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_upload_outlined,
                color: AppColors.primary,
                size: 36,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Select Audio File',
              style: AppTypography.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Supported: MP3, WAV, FLAC, M4A, AAC, OGG (Max 100MB)',
              style: AppTypography.labelSmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSection(AudioUploadState state) {
    final progress = state.uploadProgress;
    final percentage = (progress * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Uploading to Object Storage...',
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '$percentage%',
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            child: LinearProgressIndicator(
              value: progress > 0 ? progress : null,
              minHeight: 6,
              backgroundColor: AppColors.surfaceElevated,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessCard(AudioUploadState state) {
    final track = state.uploadedTrack;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline_rounded,
                  color: AppColors.success,
                  size: AppSpacing.iconLg,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upload Complete!',
                      style: AppTypography.headlineMedium.copyWith(
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Track saved and queued for processing.',
                      style: AppTypography.labelSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (track != null) ...[
            const SizedBox(height: AppSpacing.md),
            const Divider(),
            const SizedBox(height: AppSpacing.sm),
            _buildDetailRow('Title', track.title),
            if (track.artistName != null)
              _buildDetailRow('Artist', track.artistName!),
            if (track.albumName != null)
              _buildDetailRow('Album', track.albumName!),
            if (track.genre != null) _buildDetailRow('Genre', track.genre!),
            _buildDetailRow('Status', track.status),
            if (track.latestJob != null)
              _buildDetailRow(
                'Processing',
                '${track.latestJob!.jobType} (${track.latestJob!.status})',
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.labelSmall,
          ),
          Text(
            value,
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: AppSpacing.iconMd),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTypography.labelSmall.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
