import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/core/theme/app_spacing.dart';
import 'package:hums_mobile/core/theme/app_typography.dart';
import 'package:hums_mobile/core/widgets/hums_button.dart';
import 'package:hums_mobile/features/audio_player/domain/entities/player_queue.dart';
import 'package:hums_mobile/features/audio_player/presentation/providers/audio_player_provider.dart';
import 'package:hums_mobile/features/recommendations/domain/entities/recommendation_section_entity.dart';
import 'package:hums_mobile/features/recommendations/presentation/widgets/recommendation_track_card.dart';

class RecommendationSectionWidget extends ConsumerWidget {
  final RecommendationSectionEntity section;

  const RecommendationSectionWidget({
    super.key,
    required this.section,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (section.items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.title,
                      style: AppTypography.headlineMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (section.description != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        section.description!,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              HumsButton(
                label: 'Play All',
                variant: HumsButtonVariant.secondary,
                onPressed: () {
                  final playableItems = section.items
                      .where((t) => t.isPlayable)
                      .map((t) => QueueItem(
                            trackId: t.id,
                            title: t.title,
                            artistName: t.artistName,
                            albumName: t.albumName,
                            durationSeconds: t.durationSeconds,
                            waveformKey: t.waveformKey,
                            status: t.status,
                          ))
                      .toList();
                  if (playableItems.isNotEmpty) {
                    final queue = PlayerQueue(
                      playlistName: section.title,
                      items: playableItems,
                    );
                    ref
                        .read(audioPlayerNotifierProvider.notifier)
                        .playQueue(queue);
                  }
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        // Horizontal Track Carousel
        SizedBox(
          height: 215,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            scrollDirection: Axis.horizontal,
            itemCount: section.items.length,
            itemBuilder: (context, index) {
              final track = section.items[index];
              return RecommendationTrackCard(track: track);
            },
          ),
        ),

        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}
