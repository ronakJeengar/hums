import 'package:hums_mobile/features/notifications/domain/entities/notification_item.dart';
import 'package:hums_mobile/features/notifications/domain/entities/notification_preferences.dart';

class NotificationItemModel {
  final String id;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;

  const NotificationItemModel({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.data,
    required this.isRead,
    this.readAt,
    required this.createdAt,
  });

  factory NotificationItemModel.fromJson(Map<String, dynamic> json) {
    return NotificationItemModel(
      id: json['id'] as String,
      type: (json['type'] as String?) ?? 'SYSTEM',
      title: (json['title'] as String?) ?? '',
      body: (json['body'] as String?) ?? '',
      data: json['data'] != null ? Map<String, dynamic>.from(json['data'] as Map) : null,
      isRead: (json['is_read'] as bool?) ?? false,
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at'] as String) : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  NotificationItemEntity toEntity() {
    return NotificationItemEntity(
      id: id,
      type: type,
      title: title,
      body: body,
      data: data,
      isRead: isRead,
      readAt: readAt,
      createdAt: createdAt,
    );
  }
}

class NotificationPreferencesModel {
  final bool pushEnabled;
  final bool newReleasesEnabled;
  final bool playlistUpdatesEnabled;
  final bool recommendationsEnabled;
  final bool processingUpdatesEnabled;

  const NotificationPreferencesModel({
    required this.pushEnabled,
    required this.newReleasesEnabled,
    required this.playlistUpdatesEnabled,
    required this.recommendationsEnabled,
    required this.processingUpdatesEnabled,
  });

  factory NotificationPreferencesModel.fromJson(Map<String, dynamic> json) {
    return NotificationPreferencesModel(
      pushEnabled: (json['push_enabled'] as bool?) ?? true,
      newReleasesEnabled: (json['new_releases_enabled'] as bool?) ?? true,
      playlistUpdatesEnabled: (json['playlist_updates_enabled'] as bool?) ?? true,
      recommendationsEnabled: (json['recommendations_enabled'] as bool?) ?? true,
      processingUpdatesEnabled: (json['processing_updates_enabled'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'push_enabled': pushEnabled,
      'new_releases_enabled': newReleasesEnabled,
      'playlist_updates_enabled': playlistUpdatesEnabled,
      'recommendations_enabled': recommendationsEnabled,
      'processing_updates_enabled': processingUpdatesEnabled,
    };
  }

  NotificationPreferencesEntity toEntity() {
    return NotificationPreferencesEntity(
      pushEnabled: pushEnabled,
      newReleasesEnabled: newReleasesEnabled,
      playlistUpdatesEnabled: playlistUpdatesEnabled,
      recommendationsEnabled: recommendationsEnabled,
      processingUpdatesEnabled: processingUpdatesEnabled,
    );
  }
}

class NotificationListModel {
  final List<NotificationItemModel> items;
  final int total;
  final int skip;
  final int limit;

  const NotificationListModel({
    required this.items,
    required this.total,
    required this.skip,
    required this.limit,
  });

  factory NotificationListModel.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List<dynamic>?) ?? [];
    return NotificationListModel(
      items: rawItems
          .map((i) => NotificationItemModel.fromJson(i as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      skip: (json['skip'] as num?)?.toInt() ?? 0,
      limit: (json['limit'] as num?)?.toInt() ?? 50,
    );
  }
}
