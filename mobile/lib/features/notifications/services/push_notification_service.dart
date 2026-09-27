import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hums_mobile/features/notifications/domain/entities/notification_item.dart';
import 'package:hums_mobile/features/notifications/domain/repositories/notification_repository.dart';
import 'package:hums_mobile/features/notifications/presentation/providers/notification_provider.dart';

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  final repository = ref.watch(notificationRepositoryProvider);
  return PushNotificationService(ref, repository);
});

class PushNotificationService {
  final Ref _ref;
  final NotificationRepository _repository;
  String? _currentToken;
  bool _initialized = false;

  PushNotificationService(this._ref, this._repository);

  String? get currentToken => _currentToken;

  /// Initializes push notification capabilities, requests user permissions,
  /// and listens for incoming messages and token updates.
  Future<void> initialize({GoRouter? router}) async {
    if (_initialized) return;

    // Push notifications are primarily supported on mobile platforms
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      debugPrint('[PushNotificationService] Push notifications skipped on unsupported platform.');
      return;
    }

    try {
      // Ensure Firebase Core is initialized
      try {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp();
        }
      } catch (firebaseErr) {
        debugPrint('[PushNotificationService] Firebase.initializeApp() warning: $firebaseErr');
        // If native configuration files are not present in dev, continue gracefully
        return;
      }

      final messaging = FirebaseMessaging.instance;

      // 1. Request OS permission (iOS & Android 13+)
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint(
        '[PushNotificationService] User granted permission status: ${settings.authorizationStatus}',
      );

      // 2. Fetch initial device token and register with backend
      try {
        final token = await messaging.getToken();
        if (token != null) {
          _currentToken = token;
          await _registerToken(token);
        }
      } catch (tokenErr) {
        debugPrint('[PushNotificationService] Could not retrieve FCM token: $tokenErr');
      }

      // 3. Listen for token refreshes
      messaging.onTokenRefresh.listen((newToken) {
        debugPrint('[PushNotificationService] FCM token refreshed: ${newToken.substring(0, 10)}...');
        _currentToken = newToken;
        _registerToken(newToken);
      });

      // 4. Handle foreground notifications
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[PushNotificationService] Received foreground message: ${message.messageId}');
        _handleForegroundMessage(message);
      });

      // 5. Handle notification click when app is opened from background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[PushNotificationService] Notification opened from background: ${message.messageId}');
        _handleMessageTap(message, router);
      });

      // 6. Handle notification click when app launched from terminated state
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[PushNotificationService] App launched via notification click: ${initialMessage.messageId}');
        _handleMessageTap(initialMessage, router);
      }

      _initialized = true;
    } catch (e, stackTrace) {
      debugPrint('[PushNotificationService] Push service initialization failed: $e\n$stackTrace');
    }
  }

  Future<void> _registerToken(String token) async {
    try {
      final platformStr = Platform.isIOS ? 'IOS' : 'ANDROID';
      await _repository.registerDevice(
        token: token,
        platform: platformStr,
        deviceName: Platform.operatingSystem,
        appVersion: '1.0.0',
      );
      debugPrint('[PushNotificationService] Successfully registered device push token with Hums backend.');
    } catch (e) {
      debugPrint('[PushNotificationService] Failed to register token with backend: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    final notifItem = NotificationItemEntity(
      id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      type: message.data['type'] as String? ?? 'SYSTEM',
      title: notification.title ?? 'Notification',
      body: notification.body ?? '',
      data: message.data,
      isRead: false,
      createdAt: DateTime.now(),
    );

    _ref.read(notificationInboxNotifierProvider.notifier).addIncomingNotification(notifItem);
  }

  void _handleMessageTap(RemoteMessage message, GoRouter? router) {
    if (router == null) return;

    final data = message.data;
    final playlistId = data['playlist_id'] as String?;
    final trackId = data['track_id'] as String?;
    final screen = data['screen'] as String?;

    if (playlistId != null && playlistId.isNotEmpty) {
      router.push('/playlists/$playlistId');
    } else if (trackId != null && trackId.isNotEmpty) {
      router.push('/tracks');
    } else if (screen == 'notifications') {
      router.push('/notifications');
    } else if (screen == 'playlists') {
      router.push('/playlists');
    } else {
      router.push('/notifications');
    }
  }

  /// Deactivates device token on logout
  Future<void> onLogout() async {
    if (_currentToken != null) {
      try {
        await _repository.deactivateDeviceToken(_currentToken!);
        _currentToken = null;
      } catch (e) {
        debugPrint('[PushNotificationService] Error deactivating token on logout: $e');
      }
    }
  }
}
