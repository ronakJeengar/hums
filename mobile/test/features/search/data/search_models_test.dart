import 'package:flutter_test/flutter_test.dart';
import 'package:hums_mobile/features/search/data/models/search_artist_model.dart';
import 'package:hums_mobile/features/search/data/models/search_playlist_model.dart';
import 'package:hums_mobile/features/search/data/models/search_result_model.dart';
import 'package:hums_mobile/features/search/data/models/search_track_model.dart';
import 'package:hums_mobile/features/search/domain/entities/search_result_entity.dart';

void main() {
  group('Search Models Serialization Tests', () {
    test('SearchTrackModel deserializes from and serializes to JSON correctly', () {
      final json = {
        'id': 't-123',
        'owner_id': 'u-456',
        'title': 'Tum Hi Ho',
        'description': 'Romantic melody',
        'artist_name': 'Arijit Singh',
        'album_name': 'Aashiqui 2',
        'genre': 'Bollywood',
        'duration_seconds': 262,
        'waveform_key': 'waveforms/t-123.json',
        'status': 'READY',
        'created_at': '2026-09-20T12:00:00.000Z',
        'updated_at': '2026-09-20T12:05:00.000Z',
      };

      final model = SearchTrackModel.fromJson(json);
      expect(model.id, 't-123');
      expect(model.ownerId, 'u-456');
      expect(model.title, 'Tum Hi Ho');
      expect(model.artistName, 'Arijit Singh');
      expect(model.albumName, 'Aashiqui 2');
      expect(model.genre, 'Bollywood');
      expect(model.durationSeconds, 262);
      expect(model.status, 'READY');
      expect(model.isPlayable, true);
      expect(model.formattedDuration, '04:22');

      final serialized = model.toJson();
      expect(serialized['id'], 't-123');
      expect(serialized['title'], 'Tum Hi Ho');
      expect(serialized['artist_name'], 'Arijit Singh');
    });

    test('SearchArtistModel deserializes from and serializes to JSON correctly', () {
      final json = {
        'id': 'a-101',
        'name': 'Pritam',
        'username': 'pritam_composer',
        'avatar_url': 'https://example.com/avatar.jpg',
        'bio': 'Film score composer',
        'track_count': 18,
      };

      final model = SearchArtistModel.fromJson(json);
      expect(model.id, 'a-101');
      expect(model.name, 'Pritam');
      expect(model.username, 'pritam_composer');
      expect(model.avatarUrl, 'https://example.com/avatar.jpg');
      expect(model.bio, 'Film score composer');
      expect(model.trackCount, 18);

      final serialized = model.toJson();
      expect(serialized['id'], 'a-101');
      expect(serialized['name'], 'Pritam');
      expect(serialized['track_count'], 18);
    });

    test('SearchPlaylistModel deserializes from and serializes to JSON correctly', () {
      final json = {
        'id': 'p-202',
        'owner_id': 'u-456',
        'name': 'Monsoon Acoustic',
        'description': 'Calming acoustic tracks for rainy evenings',
        'cover_image_key': 'covers/p-202.jpg',
        'cover_image_url': 'https://example.com/p-202.jpg',
        'is_public': true,
        'track_count': 12,
        'created_at': '2026-09-21T08:00:00.000Z',
        'updated_at': '2026-09-21T08:30:00.000Z',
      };

      final model = SearchPlaylistModel.fromJson(json);
      expect(model.id, 'p-202');
      expect(model.ownerId, 'u-456');
      expect(model.name, 'Monsoon Acoustic');
      expect(model.isPublic, true);
      expect(model.trackCount, 12);
      expect(model.coverImageUrl, 'https://example.com/p-202.jpg');

      final serialized = model.toJson();
      expect(serialized['id'], 'p-202');
      expect(serialized['name'], 'Monsoon Acoustic');
      expect(serialized['is_public'], true);
    });

    test('SearchResultModel aggregates categorized items and counts', () {
      final json = {
        'query': 'Arijit',
        'type': 'all',
        'total_tracks': 1,
        'total_artists': 1,
        'total_playlists': 1,
        'tracks': [
          {
            'id': 't-1',
            'owner_id': 'u-1',
            'title': 'Channa Mereya',
            'artist_name': 'Arijit Singh',
            'duration_seconds': 289,
            'status': 'READY',
            'created_at': '2026-09-20T12:00:00.000Z',
            'updated_at': '2026-09-20T12:05:00.000Z',
          }
        ],
        'artists': [
          {
            'id': 'a-1',
            'name': 'Arijit Singh',
            'track_count': 12,
          }
        ],
        'playlists': [
          {
            'id': 'p-1',
            'owner_id': 'u-1',
            'name': 'Arijit Singh Essentials',
            'is_public': true,
            'track_count': 10,
            'created_at': '2026-09-20T12:00:00.000Z',
            'updated_at': '2026-09-20T12:05:00.000Z',
          }
        ],
      };

      final model = SearchResultModel.fromJson(json, category: SearchCategory.all);
      expect(model.query, 'Arijit');
      expect(model.category, SearchCategory.all);
      expect(model.totalTracks, 1);
      expect(model.totalArtists, 1);
      expect(model.totalPlaylists, 1);
      expect(model.tracks.length, 1);
      expect(model.artists.length, 1);
      expect(model.playlists.length, 1);
      expect(model.isNotEmpty, true);
    });
  });
}
