import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hums_mobile/core/theme/app_colors.dart';
import 'package:hums_mobile/core/theme/app_radii.dart';
import 'package:hums_mobile/core/theme/app_spacing.dart';
import 'package:hums_mobile/core/theme/app_typography.dart';
import 'package:hums_mobile/core/widgets/hums_button.dart';
import 'package:hums_mobile/features/audio_player/presentation/widgets/mini_player.dart';
import 'package:hums_mobile/features/audio_player/presentation/providers/audio_player_provider.dart';
import 'package:hums_mobile/features/search/domain/entities/search_result_entity.dart';
import 'package:hums_mobile/features/search/presentation/providers/search_provider.dart';
import 'package:hums_mobile/features/search/presentation/states/search_state.dart';
import 'package:hums_mobile/features/search/presentation/widgets/recent_searches_widget.dart';
import 'package:hums_mobile/features/search/presentation/widgets/search_album_tile.dart';
import 'package:hums_mobile/features/search/presentation/widgets/search_artist_tile.dart';
import 'package:hums_mobile/features/search/presentation/widgets/search_bar_widget.dart';
import 'package:hums_mobile/features/search/presentation/widgets/search_filter_chips.dart';
import 'package:hums_mobile/features/search/presentation/widgets/search_playlist_tile.dart';
import 'package:hums_mobile/features/search/presentation/widgets/search_suggestions_list.dart';
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
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: SearchBarWidget(
          controller: _controller,
          onChanged: (val) => notifier.onQueryChanged(val),
          onClear: () {
            _controller.clear();
            notifier.clearSearch();
          },
          onSubmitted: () => notifier.searchNow(),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter chips header
            Container(
              color: AppColors.background,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: SearchFilterChips(
                selectedCategory: searchState.category,
                onCategorySelected: (cat) => notifier.onCategoryChanged(cat),
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),

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
    SearchState searchState,
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
              'Searching Hums catalog...',
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
              const Icon(
                Icons.cloud_off_rounded,
                color: AppColors.error,
                size: 48,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                "Couldn't load search results.",
                style: AppTypography.headlineMedium.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Please check your network connection and try again.',
                style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
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

    // Show suggestions list if typing and suggestions are available
    if (searchState.suggestions.isNotEmpty && searchState.query.isNotEmpty && !searchState.isLoaded) {
      return SingleChildScrollView(
        child: SearchSuggestionsList(
          suggestions: searchState.suggestions,
          onSelect: (sugg) {
            _controller.text = sugg;
            notifier.selectSuggestion(sugg);
          },
        ),
      );
    }

    if (searchState.isInitial) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recent searches widget
            if (searchState.recentSearches.isNotEmpty)
              RecentSearchesWidget(
                recentSearches: searchState.recentSearches,
                onSelect: (query) {
                  _controller.text = query;
                  notifier.selectRecentSearch(query);
                },
                onRemove: (query) => notifier.removeRecentSearch(query),
                onClearAll: () => notifier.clearRecentSearches(),
              ),

            // Explore empty prompt
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceElevated,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.search_rounded,
                        color: AppColors.primary,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Text(
                      'Explore the Catalog',
                      style: AppTypography.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Search for songs, artists, albums, and playlists across Hums.',
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            // Spotify-style "Browse All / Genres" Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Browse All',
                    style: AppTypography.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: AppSpacing.sm,
                    crossAxisSpacing: AppSpacing.sm,
                    childAspectRatio: 1.8,
                    children: [
                      _buildGenreCard(
                        context,
                        title: 'Acoustic\nSessions',
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6633), Color(0xFFC2410C)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        icon: Icons.album_rounded,
                        onTap: () {
                          _controller.text = 'Acoustic';
                          notifier.onQueryChanged('Acoustic');
                        },
                      ),
                      _buildGenreCard(
                        context,
                        title: 'Podcasts\n& Audio',
                        gradient: const LinearGradient(
                          colors: [Color(0xFFA855F7), Color(0xFF6B21A8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        icon: Icons.mic_rounded,
                        onTap: () {
                          _controller.text = 'Podcast';
                          notifier.onQueryChanged('Podcast');
                        },
                      ),
                      _buildGenreCard(
                        context,
                        title: 'Indie &\nFolk',
                        gradient: const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF065F46)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        icon: Icons.music_note_rounded,
                        onTap: () {
                          _controller.text = 'Indie';
                          notifier.onQueryChanged('Indie');
                        },
                      ),
                      _buildGenreCard(
                        context,
                        title: 'Ambient &\nFocus',
                        gradient: const LinearGradient(
                          colors: [Color(0xFF38BDF8), Color(0xFF0369A1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        icon: Icons.graphic_eq_rounded,
                        onTap: () {
                          _controller.text = 'Ambient';
                          notifier.onQueryChanged('Ambient');
                        },
                      ),
                      _buildGenreCard(
                        context,
                        title: 'New\nReleases',
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF43F5E), Color(0xFF9F1239)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        icon: Icons.auto_awesome_rounded,
                        onTap: () {
                          _controller.text = 'New';
                          notifier.onQueryChanged('New');
                        },
                      ),
                      _buildGenreCard(
                        context,
                        title: 'Chill &\nRelax',
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF3730A3)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        icon: Icons.nightlife_rounded,
                        onTap: () {
                          _controller.text = 'Chill';
                          notifier.onQueryChanged('Chill');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ],
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
              const Text(
                'No Results Found',
                style: AppTypography.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'No matches found for "${searchState.query}".',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Try:',
                      style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '• Checking your spelling',
                      style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary),
                    ),
                    Text(
                      '• Searching by artist or singer name',
                      style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary),
                    ),
                    Text(
                      '• Searching by song title or album',
                      style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final results = searchState.results;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      children: [
        // Tracks (Songs) Section
        if (results.tracks.isNotEmpty) ...[
          _buildSectionHeader(
            title: 'Songs',
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
                if (artist.id.isNotEmpty && !artist.id.startsWith('artist_')) {
                  context.push('/creators/${artist.id}');
                } else {
                  _controller.text = artist.name;
                  notifier.onQueryChanged(artist.name);
                  notifier.onCategoryChanged(SearchCategory.tracks);
                }
              },
            );
          }),
          const SizedBox(height: AppSpacing.md),
        ],

        // Albums Section
        if (results.albums.isNotEmpty) ...[
          _buildSectionHeader(
            title: 'Albums',
            count: results.totalAlbums,
            showSeeAll: searchState.category == SearchCategory.all && results.totalAlbums > results.albums.length,
            onSeeAll: () => notifier.onCategoryChanged(SearchCategory.albums),
          ),
          ...results.albums.map((album) {
            return SearchAlbumTile(
              album: album,
              onTap: () {
                _controller.text = album.title;
                notifier.onQueryChanged(album.title);
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

  Widget _buildGenreCard(
    BuildContext context, {
    required String title,
    required Gradient gradient,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Container(
        height: 84,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(AppRadii.md),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
                height: 1.2,
              ),
            ),
            Positioned(
              right: -6,
              bottom: -6,
              child: Transform.rotate(
                angle: 0.2,
                child: Icon(
                  icon,
                  size: 40,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
