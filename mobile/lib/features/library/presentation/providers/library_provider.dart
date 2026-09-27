import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hums_mobile/core/network/api_client.dart';
import 'package:hums_mobile/features/library/data/datasources/library_remote_data_source.dart';
import 'package:hums_mobile/features/library/data/repositories/library_repository_impl.dart';
import 'package:hums_mobile/features/library/domain/entities/liked_track_entity.dart';
import 'package:hums_mobile/features/library/domain/entities/library_summary_entity.dart';
import 'package:hums_mobile/features/library/domain/repositories/library_repository.dart';

final libraryRemoteDataSourceProvider = Provider<LibraryRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return LibraryRemoteDataSourceImpl(apiClient);
});

final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  final remoteDataSource = ref.watch(libraryRemoteDataSourceProvider);
  return LibraryRepositoryImpl(remoteDataSource);
});

final librarySummaryProvider = FutureProvider<LibrarySummaryEntity>((ref) async {
  final repository = ref.watch(libraryRepositoryProvider);
  return repository.getLibrarySummary();
});

class LikedTracksState {
  final List<LikedTrackEntity> tracks;
  final bool isLoading;
  final bool isFetchingNextPage;
  final bool hasNext;
  final int page;
  final String? errorMessage;

  const LikedTracksState({
    this.tracks = const [],
    this.isLoading = false,
    this.isFetchingNextPage = false,
    this.hasNext = true,
    this.page = 1,
    this.errorMessage,
  });

  LikedTracksState copyWith({
    List<LikedTrackEntity>? tracks,
    bool? isLoading,
    bool? isFetchingNextPage,
    bool? hasNext,
    int? page,
    String? errorMessage,
  }) {
    return LikedTracksState(
      tracks: tracks ?? this.tracks,
      isLoading: isLoading ?? this.isLoading,
      isFetchingNextPage: isFetchingNextPage ?? this.isFetchingNextPage,
      hasNext: hasNext ?? this.hasNext,
      page: page ?? this.page,
      errorMessage: errorMessage,
    );
  }
}

class LikedTracksNotifier extends StateNotifier<LikedTracksState> {
  final LibraryRepository _repository;

  LikedTracksNotifier(this._repository) : super(const LikedTracksState()) {
    loadInitial();
  }

  Future<void> loadInitial() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final items = await _repository.getLikedTracks(page: 1, size: 20);
      state = state.copyWith(
        tracks: items,
        isLoading: false,
        page: 1,
        hasNext: items.length >= 20,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load liked songs. Please try again.',
      );
    }
  }

  Future<void> loadNextPage() async {
    if (state.isLoading || state.isFetchingNextPage || !state.hasNext) return;

    state = state.copyWith(isFetchingNextPage: true);
    final nextPage = state.page + 1;
    try {
      final items = await _repository.getLikedTracks(page: nextPage, size: 20);
      state = state.copyWith(
        tracks: [...state.tracks, ...items],
        isFetchingNextPage: false,
        page: nextPage,
        hasNext: items.length >= 20,
      );
    } catch (e) {
      state = state.copyWith(isFetchingNextPage: false);
    }
  }

  Future<void> refresh() async {
    await loadInitial();
  }

  void removeTrack(String trackId) {
    state = state.copyWith(
      tracks: state.tracks.where((t) => t.id != trackId).toList(),
    );
  }
}

final likedTracksNotifierProvider =
    StateNotifierProvider<LikedTracksNotifier, LikedTracksState>((ref) {
  final repository = ref.watch(libraryRepositoryProvider);
  return LikedTracksNotifier(repository);
});
