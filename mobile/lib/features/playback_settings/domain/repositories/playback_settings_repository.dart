import 'package:hums_mobile/features/playback_settings/domain/entities/playback_settings_entity.dart';

abstract class PlaybackSettingsRepository {
  Future<PlaybackSettingsEntity> getSettings();
  Future<PlaybackSettingsEntity> updateSettings(PlaybackSettingsEntity settings);
}
