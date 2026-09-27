import 'package:hums_mobile/features/recommendations/domain/entities/recommendation_section_entity.dart';

enum RecommendationStatus {
  initial,
  loading,
  loaded,
  error,
}

class RecommendationState {
  final RecommendationStatus status;
  final List<RecommendationSectionEntity> sections;
  final String? errorMessage;
  final bool isRefreshing;

  const RecommendationState({
    this.status = RecommendationStatus.initial,
    this.sections = const [],
    this.errorMessage,
    this.isRefreshing = false,
  });

  RecommendationState copyWith({
    RecommendationStatus? status,
    List<RecommendationSectionEntity>? sections,
    String? errorMessage,
    bool? isRefreshing,
    bool clearError = false,
  }) {
    return RecommendationState(
      status: status ?? this.status,
      sections: sections ?? this.sections,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }

  bool get isInitial => status == RecommendationStatus.initial;
  bool get isLoading => status == RecommendationStatus.loading;
  bool get isLoaded => status == RecommendationStatus.loaded;
  bool get hasError => status == RecommendationStatus.error && errorMessage != null;
  bool get isEmpty =>
      isLoaded && (sections.isEmpty || sections.every((s) => s.items.isEmpty));
}
