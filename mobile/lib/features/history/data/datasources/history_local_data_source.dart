import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:hums_mobile/features/history/data/models/playback_event_model.dart';
import 'package:hums_mobile/features/history/data/models/playback_progress_model.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

abstract class HistoryLocalDataSource {
  Future<void> init();

  /// Enqueues events into the user's persistent offline event queue.
  Future<void> enqueueEvents(String userId, List<PlaybackEventModel> events);

  /// Retrieves all un-synced offline events for a user.
  Future<List<PlaybackEventModel>> getPendingEvents(String userId);

  /// Dequeues events by ID after successful synchronization.
  Future<void> removeEvents(String userId, List<String> eventIds);

  /// Caches the latest playback progress locally for instant offline resume.
  Future<void> saveProgress(String userId, PlaybackProgressModel progress);

  /// Retrieves locally cached playback progress for a track.
  Future<PlaybackProgressModel?> getProgress(String userId, String trackId);

  /// Clears user-scoped local history caches and queues.
  Future<void> clearUserData(String userId);
}

class FileStorageHistoryLocalDataSourceImpl implements HistoryLocalDataSource {
  final Directory? _baseDirOverride;
  final Map<String, List<PlaybackEventModel>> _userEvents = {};
  final Map<String, Map<String, PlaybackProgressModel>> _userProgress = {};

  FileStorageHistoryLocalDataSourceImpl({Directory? baseDirectory})
      : _baseDirOverride = baseDirectory;

  Future<Directory> _getUserDir(String userId) async {
    final Directory base;
    if (_baseDirOverride != null) {
      base = _baseDirOverride;
    } else {
      final appDocDir = await getApplicationDocumentsDirectory();
      base = Directory(p.join(appDocDir.path, 'history'));
    }
    final userDir = Directory(p.join(base.path, userId));
    if (!await userDir.exists()) {
      await userDir.create(recursive: true);
    }
    return userDir;
  }

  @override
  Future<void> init() async {}

  Future<void> _loadUserEvents(String userId) async {
    if (_userEvents.containsKey(userId)) return;
    try {
      final userDir = await _getUserDir(userId);
      final file = File(p.join(userDir.path, 'offline_events.json'));
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final decoded = json.decode(content) as List<dynamic>;
          final list = <PlaybackEventModel>[];
          for (final raw in decoded) {
            try {
              list.add(PlaybackEventModel.fromJson(raw as Map<String, dynamic>));
            } catch (_) {}
          }
          _userEvents[userId] = list;
          return;
        }
      }
    } catch (_) {}
    _userEvents[userId] = [];
  }

  Future<void> _persistUserEvents(String userId) async {
    try {
      final userDir = await _getUserDir(userId);
      final file = File(p.join(userDir.path, 'offline_events.json'));
      final tmpFile = File('${file.path}.tmp');

      final list = _userEvents[userId] ?? [];
      final encoded = json.encode(list.map((e) => e.toJson()).toList());

      await tmpFile.writeAsString(encoded, flush: true);
      await tmpFile.rename(file.path);
    } catch (_) {}
  }

  Future<void> _loadUserProgress(String userId) async {
    if (_userProgress.containsKey(userId)) return;
    try {
      final userDir = await _getUserDir(userId);
      final file = File(p.join(userDir.path, 'offline_progress.json'));
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final decoded = json.decode(content) as List<dynamic>;
          final map = <String, PlaybackProgressModel>{};
          for (final raw in decoded) {
            try {
              final model = PlaybackProgressModel.fromJson(raw as Map<String, dynamic>);
              map[model.trackId] = model;
            } catch (_) {}
          }
          _userProgress[userId] = map;
          return;
        }
      }
    } catch (_) {}
    _userProgress[userId] = {};
  }

  Future<void> _persistUserProgress(String userId) async {
    try {
      final userDir = await _getUserDir(userId);
      final file = File(p.join(userDir.path, 'offline_progress.json'));
      final tmpFile = File('${file.path}.tmp');

      final map = _userProgress[userId] ?? {};
      final encoded = json.encode(map.values.map((p) => p.toJson()).toList());

      await tmpFile.writeAsString(encoded, flush: true);
      await tmpFile.rename(file.path);
    } catch (_) {}
  }

  @override
  Future<void> enqueueEvents(String userId, List<PlaybackEventModel> events) async {
    await _loadUserEvents(userId);
    final currentList = _userEvents[userId] ?? [];

    final existingIds = currentList.map((e) => e.eventId).toSet();
    for (final ev in events) {
      if (!existingIds.contains(ev.eventId)) {
        currentList.add(ev);
        existingIds.add(ev.eventId);
      }
    }
    _userEvents[userId] = currentList;
    await _persistUserEvents(userId);
  }

  @override
  Future<List<PlaybackEventModel>> getPendingEvents(String userId) async {
    await _loadUserEvents(userId);
    return List.unmodifiable(_userEvents[userId] ?? []);
  }

  @override
  Future<void> removeEvents(String userId, List<String> eventIds) async {
    await _loadUserEvents(userId);
    final currentList = _userEvents[userId] ?? [];
    final idSet = eventIds.toSet();

    currentList.removeWhere((ev) => idSet.contains(ev.eventId));
    _userEvents[userId] = currentList;
    await _persistUserEvents(userId);
  }

  @override
  Future<void> saveProgress(String userId, PlaybackProgressModel progress) async {
    await _loadUserProgress(userId);
    final currentMap = _userProgress[userId] ?? {};
    currentMap[progress.trackId] = progress;
    _userProgress[userId] = currentMap;
    await _persistUserProgress(userId);
  }

  @override
  Future<PlaybackProgressModel?> getProgress(String userId, String trackId) async {
    await _loadUserProgress(userId);
    return _userProgress[userId]?[trackId];
  }

  @override
  Future<void> clearUserData(String userId) async {
    _userEvents.remove(userId);
    _userProgress.remove(userId);
    try {
      final userDir = await _getUserDir(userId);
      if (await userDir.exists()) {
        await userDir.delete(recursive: true);
      }
    } catch (_) {}
  }
}
