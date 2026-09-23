class NotificationPreferencesEntity {
  final bool pushEnabled;
  final bool newReleasesEnabled;
  final bool playlistUpdatesEnabled;
  final bool recommendationsEnabled;
  final bool processingUpdatesEnabled;

  const NotificationPreferencesEntity({
    this.pushEnabled = true,
    this.newReleasesEnabled = true,
    this.playlistUpdatesEnabled = true,
    this.recommendationsEnabled = true,
    this.processingUpdatesEnabled = true,
  });

  NotificationPreferencesEntity copyWith({
    bool? pushEnabled,
    bool? newReleasesEnabled,
    bool? playlistUpdatesEnabled,
    bool? recommendationsEnabled,
    bool? processingUpdatesEnabled,
  }) {
    return NotificationPreferencesEntity(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      newReleasesEnabled: newReleasesEnabled ?? this.newReleasesEnabled,
      playlistUpdatesEnabled:
          playlistUpdatesEnabled ?? this.playlistUpdatesEnabled,
      recommendationsEnabled:
          recommendationsEnabled ?? this.recommendationsEnabled,
      processingUpdatesEnabled:
          processingUpdatesEnabled ?? this.processingUpdatesEnabled,
    );
  }
}
