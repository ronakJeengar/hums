import 'package:flutter/material.dart';

class NotificationItemEntity {
  final String id;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;

  const NotificationItemEntity({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.data,
    required this.isRead,
    this.readAt,
    required this.createdAt,
  });

  NotificationItemEntity copyWith({
    String? id,
    String? type,
    String? title,
    String? body,
    Map<String, dynamic>? data,
    bool? isRead,
    DateTime? readAt,
    DateTime? createdAt,
  }) {
    return NotificationItemEntity(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  IconData get iconData {
    switch (type.toUpperCase()) {
      case 'UPLOAD_COMPLETE':
      case 'TRANSCRIPTION_COMPLETE':
        return Icons.cloud_done_rounded;
      case 'PLAYLIST_UPDATE':
        return Icons.queue_music_rounded;
      case 'NEW_RELEASE':
        return Icons.album_rounded;
      case 'RECOMMENDATION_READY':
        return Icons.auto_awesome_rounded;
      case 'SYSTEM':
      default:
        return Icons.notifications_rounded;
    }
  }

  Color get iconColor {
    switch (type.toUpperCase()) {
      case 'UPLOAD_COMPLETE':
      case 'TRANSCRIPTION_COMPLETE':
        return const Color(0xFF00C853);
      case 'PLAYLIST_UPDATE':
        return const Color(0xFF2979FF);
      case 'NEW_RELEASE':
        return const Color(0xFFFF9100);
      case 'RECOMMENDATION_READY':
        return const Color(0xFFAA00FF);
      default:
        return const Color(0xFF8E8E93);
    }
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    }
  }

  /// Extracts deep-link route if available from notification data payload
  String? get deepLinkRoute {
    if (data == null) return null;
    final screen = data!['screen'] as String?;
    final trackId = data!['track_id'] as String?;
    final playlistId = data!['playlist_id'] as String?;

    if (playlistId != null && playlistId.isNotEmpty) {
      return '/playlists/$playlistId';
    }
    if (trackId != null && trackId.isNotEmpty) {
      return '/tracks';
    }
    if (screen != null && screen.isNotEmpty) {
      switch (screen.toLowerCase()) {
        case 'playlists':
          return '/playlists';
        case 'profile':
          return '/profile';
        case 'home':
          return '/home';
        default:
          return null;
      }
    }
    return null;
  }
}
