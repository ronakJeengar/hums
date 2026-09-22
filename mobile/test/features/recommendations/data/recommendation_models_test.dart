import 'package:flutter_test/flutter_test.dart';
import 'package:hums_mobile/features/recommendations/data/models/recommendation_section_model.dart';
import 'package:hums_mobile/features/recommendations/data/models/recommendation_track_model.dart';
import 'package:hums_mobile/features/recommendations/domain/entities/recommendation_section_entity.dart';
import 'package:hums_mobile/features/recommendations/domain/entities/recommendation_track_entity.dart';

void main() {
  group('RecommendationTrackModel & Entity Tests', () {
    final tJson = {
      'id': 'track-123',
      'title': 'Midnight Drift',
      'artist_name': 'Neon Wave',
      'album_name': 'Retro Waves',
      'genre': 'Synthwave',
      'duration_seconds': 214,
      'artwork_url': 'https://cdn.hums.audio/art/track-123.jpg',
      'status': 'READY',
      'waveform_key': 'waveforms/track-123.json',
    };

    test('fromJson parses full track payload correctly', () {
      final model = RecommendationTrackModel.fromJson(tJson);

      expect(model.id, 'track-123');
      expect(model.title, 'Midnight Drift');
      expect(model.artistName, 'Neon Wave');
      expect(model.albumName, 'Retro Waves');
      expect(model.genre, 'Synthwave');
      expect(model.durationSeconds, 214);
      expect(model.artworkUrl, 'https://cdn.hums.audio/art/track-123.jpg');
      expect(model.status, 'READY');
      expect(model.waveformKey, 'waveforms/track-123.json');
    });

    test('fromJson handles null and optional fields with defaults', () {
      final minimalJson = {
        'id': 'track-456',
      };
      final model = RecommendationTrackModel.fromJson(minimalJson);

      expect(model.id, 'track-456');
      expect(model.title, '');
      expect(model.artistName, isNull);
      expect(model.albumName, isNull);
      expect(model.genre, isNull);
      expect(model.durationSeconds, isNull);
      expect(model.artworkUrl, isNull);
      expect(model.status, 'READY');
      expect(model.waveformKey, isNull);
    });

    test('toJson serializes correctly', () {
      final model = RecommendationTrackModel.fromJson(tJson);
      final json = model.toJson();

      expect(json['id'], 'track-123');
      expect(json['title'], 'Midnight Drift');
      expect(json['artist_name'], 'Neon Wave');
      expect(json['album_name'], 'Retro Waves');
      expect(json['genre'], 'Synthwave');
      expect(json['duration_seconds'], 214);
      expect(json['artwork_url'], 'https://cdn.hums.audio/art/track-123.jpg');
      expect(json['status'], 'READY');
      expect(json['waveform_key'], 'waveforms/track-123.json');
    });

    test('toEntity converts model to RecommendationTrackEntity', () {
      final model = RecommendationTrackModel.fromJson(tJson);
      final entity = model.toEntity();

      expect(entity.id, 'track-123');
      expect(entity.title, 'Midnight Drift');
      expect(entity.artistName, 'Neon Wave');
      expect(entity.albumName, 'Retro Waves');
      expect(entity.genre, 'Synthwave');
      expect(entity.durationSeconds, 214);
      expect(entity.artworkUrl, 'https://cdn.hums.audio/art/track-123.jpg');
      expect(entity.status, 'READY');
      expect(entity.waveformKey, 'waveforms/track-123.json');
      expect(entity.isPlayable, isTrue);
      expect(entity.formattedDuration, '03:34');
    });

    test('RecommendationTrackEntity formatting edge cases', () {
      const entityNoDuration = RecommendationTrackEntity(
        id: 't-none',
        title: 'Unknown Duration',
        status: 'READY',
      );
      expect(entityNoDuration.formattedDuration, '--:--');

      const entityShort = RecommendationTrackEntity(
        id: 't-short',
        title: 'Short Ping',
        durationSeconds: 5,
        status: 'PROCESSING',
      );
      expect(entityShort.formattedDuration, '00:05');
      expect(entityShort.isPlayable, isFalse);
    });
  });

  group('RecommendationSectionModel & Entity Tests', () {
    final tSectionJson = {
      'id': 'for-you',
      'title': 'Recommended For You',
      'description': 'Handcrafted selections based on your listening taste',
      'items': [
        {
          'id': 'track-1',
          'title': 'Morning Sun',
          'artist_name': 'Solaris',
          'genre': 'Ambient',
          'duration_seconds': 180,
          'status': 'READY',
        }
      ],
    };

    test('fromJson parses section with items correctly', () {
      final model = RecommendationSectionModel.fromJson(tSectionJson);

      expect(model.id, 'for-you');
      expect(model.title, 'Recommended For You');
      expect(model.description, 'Handcrafted selections based on your listening taste');
      expect(model.items.length, 1);
      expect(model.items.first.title, 'Morning Sun');
    });

    test('fromJson handles null description and empty items', () {
      final minimal = {
        'id': 'trending',
        'title': 'Trending Right Now',
      };
      final model = RecommendationSectionModel.fromJson(minimal);

      expect(model.id, 'trending');
      expect(model.title, 'Trending Right Now');
      expect(model.description, isNull);
      expect(model.items, isEmpty);
    });

    test('toJson serializes section correctly', () {
      final model = RecommendationSectionModel.fromJson(tSectionJson);
      final json = model.toJson();

      expect(json['id'], 'for-you');
      expect(json['title'], 'Recommended For You');
      expect((json['items'] as List).length, 1);
    });

    test('toEntity converts model to RecommendationSectionEntity', () {
      final model = RecommendationSectionModel.fromJson(tSectionJson);
      final entity = model.toEntity();

      expect(entity.id, 'for-you');
      expect(entity.title, 'Recommended For You');
      expect(entity.description, 'Handcrafted selections based on your listening taste');
      expect(entity.items.length, 1);
      expect(entity.hasItems, isTrue);
    });

    test('RecommendationSectionEntity hasItems is false for empty list', () {
      const entity = RecommendationSectionEntity(
        id: 'empty',
        title: 'Empty Section',
        items: [],
      );
      expect(entity.hasItems, isFalse);
    });
  });
}
