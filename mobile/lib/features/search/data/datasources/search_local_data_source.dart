import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class SearchLocalDataSource {
  Future<List<String>> getRecentSearches();
  Future<void> saveRecentSearch(String query);
  Future<void> removeRecentSearch(String query);
  Future<void> clearRecentSearches();
}

class SearchLocalDataSourceImpl implements SearchLocalDataSource {
  static const String _key = 'hums_recent_searches_v1';
  static const int maxRecentSearches = 10;
  final FlutterSecureStorage _storage;

  const SearchLocalDataSourceImpl(this._storage);

  @override
  Future<List<String>> getRecentSearches() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> saveRecentSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;

    final current = await getRecentSearches();
    // Deduplicate case-insensitively, keeping the newest at index 0
    final updated = [
      clean,
      ...current.where((s) => s.toLowerCase() != clean.toLowerCase()),
    ];

    final trimmed = updated.take(maxRecentSearches).toList();
    await _storage.write(key: _key, value: jsonEncode(trimmed));
  }

  @override
  Future<void> removeRecentSearch(String query) async {
    final current = await getRecentSearches();
    final updated = current.where((s) => s != query).toList();
    await _storage.write(key: _key, value: jsonEncode(updated));
  }

  @override
  Future<void> clearRecentSearches() async {
    await _storage.delete(key: _key);
  }
}
