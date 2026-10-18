import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hums_mobile/features/playback_settings/domain/entities/playback_settings_entity.dart';

abstract class PlaybackSettingsLocalDataSource {
  Future<PlaybackSettingsEntity> getCachedSettings();
  Future<void> cacheSettings(PlaybackSettingsEntity settings);
  Future<void> clearSettings();
}

class PlaybackSettingsLocalDataSourceImpl implements PlaybackSettingsLocalDataSource {
  static const String _key = 'hums_playback_settings';
  final FlutterSecureStorage _storage;

  PlaybackSettingsLocalDataSourceImpl([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<PlaybackSettingsEntity> getCachedSettings() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw != null && raw.isNotEmpty) {
        final decoded = json.decode(raw) as Map<String, dynamic>;
        return PlaybackSettingsEntity.fromJson(decoded);
      }
    } catch (_) {
      // Fallback to defaults on read error
    }
    return const PlaybackSettingsEntity();
  }

  @override
  Future<void> cacheSettings(PlaybackSettingsEntity settings) async {
    try {
      final encoded = json.encode(settings.toJson());
      await _storage.write(key: _key, value: encoded);
    } catch (_) {}
  }

  @override
  Future<void> clearSettings() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {}
  }
}
