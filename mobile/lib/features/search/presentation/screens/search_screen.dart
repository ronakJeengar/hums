import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/core/theme/app_spacing.dart';
import 'package:hums_mobile/core/theme/app_typography.dart';
import 'package:hums_mobile/core/widgets/hums_button.dart';
import 'package:hums_mobile/features/audio_player/presentation/providers/audio_player_provider.dart';
import 'package:hums_mobile/features/audio_player/presentation/widgets/mini_player.dart';
import 'package:hums_mobile/features/search/domain/entities/search_result_entity.dart';
import 'package:hums_mobile/features/search/presentation/providers/search_provider.dart';
import 'package:hums_mobile/features/search/presentation/widgets/search_artist_tile.dart';
import 'package:hums_mobile/features/search/presentation/widgets/search_bar_widget.dart';
import 'package:hums_mobile/features/search/presentation/widgets/search_filter_chips.dart';
import 'package:hums_mobile/features/search/presentation/widgets/search_playlist_tile.dart';
import 'package:hums_mobile/features/search/presentation/widgets/search_track_tile.dart';

class SearchScreen extends ConsumerStatefulWidget {
  final String? initialQuery;

  const SearchScreen({
    super.key,
    this.initialQuery,
  });

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery ?? '');
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(searchNotifierProvider.notifier).onQueryChanged(widget.initialQuery!);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchNotifierProvider);
    final notifier = ref.read(searchNotifierProvider.notifier);
    final playerState = ref.watch(audioPlayerNotifierProvider);
    final currentPlayingTrackId = playerState.track?.trackId;
    final isPlaying = playerState.isPlaying;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: SearchBarWidget(
          controller: _controller,
          onChanged: (val) => notifier.onQueryChanged(val),
          onClear: () => notifier.clearSearch(),
          onSubmitted: () => notifier.searchNow(),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter chips header
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: SearchFilterChips(
                selectedCategory: searchState.category,
                onCategorySelected: (cat) => notifier.onCategoryChanged(cat),
              ),
            ),
            const Divider(height: 1, color: AppColors.border),

            // Content body
            Expanded(
              child: _buildBody(
                context,
                searchState,
                notifier,
                currentPlayingTrackId,
                isPlaying,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }

  Widget _buildBody(
    BuildContext context,
    dynamic searchState,
    SearchNotifier notifier,
    String? currentPlayingTrackId,
    bool isPlaying,
  ) {
    if (searchState.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: AppSpacing.md),
            Text(
              'Searching Hums...',
              style: AppTypography.bodyMedium,
            ),
          ],
        ),
      );
    }

    if (searchState.isError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Search Failed',
                style: AppTypography.headlineMedium.copyWith(color: AppColors.error),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                searchState.errorMessage ?? 'An error occurred while searching.',
                style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              HumsButton(
                label: 'Retry',
                variant: HumsButtonVariant.outline,
                onPressed: () => notifier.retry(),
              ),
            ],
          ),
        ),
      );
    }

    if (searchState.isInitial) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.search_rounded,
                  color: AppColors.primary,
                  size: 48,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'Explore the Catalog',
                style: AppTypography.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Search for songs, creators, playlists, and genres across Hums.',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (searchState.isEmptyResults) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.search_off_rounded,
                color: AppColors.textSecondary,
                size: 48,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'No Results Found',
                style: AppTypography.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'No matches found for "${searchState.query}". Try a different keyword or check spelling.',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Has results: render categorized list
    final results = searchState.results as SearchResultEntity;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      children: [
        // Tracks Section
        if (results.tracks.isNotEmpty) ...[
          _buildSectionHeader(
            title: 'Tracks',
            count: results.totalTracks,
            showSeeAll: searchState.category == SearchCategory.all && results.totalTracks > results.tracks.length,
            onSeeAll: () => notifier.onCategoryChanged(SearchCategory.tracks),
          ),
          ...results.tracks.map((track) {
            final isCurrent = currentPlayingTrackId == track.id;
            return SearchTrackTile(
              track: track,
              isCurrentTrack: isCurrent,
              isPlaying: isPlaying,
              onTap: () {
                if (isCurrent) {
                  ref.read(audioPlayerNotifierProvider.notifier).togglePlayPause();
                } else {
                  ref.read(audioPlayerNotifierProvider.notifier).playTrack(track.id);
                }
              },
            );
          }),
          const SizedBox(height: AppSpacing.md),
        ],

        // Artists Section
        if (results.artists.isNotEmpty) ...[
          _buildSectionHeader(
            title: 'Artists',
            count: results.totalArtists,
            showSeeAll: searchState.category == SearchCategory.all && results.totalArtists > results.artists.length,
            onSeeAll: () => notifier.onCategoryChanged(SearchCategory.artists),
          ),
          ...results.artists.map((artist) {
            return SearchArtistTile(
              artist: artist,
              onTap: () {
                _controller.text = artist.name;
                notifier.onQueryChanged(artist.name);
                notifier.onCategoryChanged(SearchCategory.tracks);
              },
            );
          }),
          const SizedBox(height: AppSpacing.md),
        ],

        // Playlists Section
        if (results.playlists.isNotEmpty) ...[
          _buildSectionHeader(
            title: 'Playlists',
            count: results.totalPlaylists,
            showSeeAll: searchState.category == SearchCategory.all && results.totalPlaylists > results.playlists.length,
            onSeeAll: () => notifier.onCategoryChanged(SearchCategory.playlists),
          ),
          ...results.playlists.map((playlist) {
            return SearchPlaylistTile(
              playlist: playlist,
              onTap: () {
                context.push('/playlists/${playlist.id}');
              },
            );
          }),
        ],
      ],
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required int count,
    bool showSeeAll = false,
    VoidCallback? onSeeAll,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                title,
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  count.toString(),
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (showSeeAll)
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
              child: const Text('See All'),
            ),
        ],
      ),
    );
  }
}
