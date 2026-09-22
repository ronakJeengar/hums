import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hums_mobile/core/network/api_client.dart';
import 'package:hums_mobile/core/network/api_exception.dart';
import 'package:hums_mobile/features/recommendations/data/datasources/recommendation_remote_data_source.dart';
import 'package:hums_mobile/features/recommendations/data/repositories/recommendation_repository_impl.dart';
import 'package:hums_mobile/features/recommendations/domain/repositories/recommendation_repository.dart';
import 'package:hums_mobile/features/recommendations/presentation/states/recommendation_state.dart';

final recommendationRemoteDataSourceProvider =
    Provider<RecommendationRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return RecommendationRemoteDataSourceImpl(apiClient);
});

final recommendationRepositoryProvider =
    Provider<RecommendationRepository>((ref) {
  final remoteDataSource = ref.watch(recommendationRemoteDataSourceProvider);
  return RecommendationRepositoryImpl(remoteDataSource);
});

final recommendationNotifierProvider =
    StateNotifierProvider<RecommendationNotifier, RecommendationState>((ref) {
  final repository = ref.watch(recommendationRepositoryProvider);
  return RecommendationNotifier(repository);
});

class RecommendationNotifier extends StateNotifier<RecommendationState> {
  final RecommendationRepository _repository;

  RecommendationNotifier(this._repository)
      : super(const RecommendationState());

  Future<void> loadRecommendations({bool refresh = false}) async {
    if (state.isLoaded && !refresh && state.sections.isNotEmpty) return;

    if (refresh) {
      state = state.copyWith(isRefreshing: true, clearError: true);
    } else {
      state = state.copyWith(
          status: RecommendationStatus.loading, clearError: true);
    }

    try {
      final sections = await _repository.getRecommendations(refresh: refresh);
      state = state.copyWith(
        status: RecommendationStatus.loaded,
        sections: sections,
        isRefreshing: false,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        status: RecommendationStatus.error,
        errorMessage: e.message,
        isRefreshing: false,
      );
    } catch (e) {
      state = state.copyWith(
        status: RecommendationStatus.error,
        errorMessage: e.toString(),
        isRefreshing: false,
      );
    }
  }

  Future<void> refresh() async {
    try {
      await _repository.refreshRecommendations();
      await loadRecommendations(refresh: true);
    } on ApiException catch (e) {
      state = state.copyWith(
        status: RecommendationStatus.error,
        errorMessage: e.message,
        isRefreshing: false,
      );
    } catch (e) {
      state = state.copyWith(
        status: RecommendationStatus.error,
        errorMessage: e.toString(),
        isRefreshing: false,
      );
    }
  }
}
