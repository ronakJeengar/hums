import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:hums_mobile/features/notifications/presentation/providers/notification_provider.dart';
import 'package:hums_mobile/features/notifications/presentation/screens/notification_screen.dart';
import 'package:hums_mobile/features/notifications/presentation/states/notification_state.dart';
import 'package:hums_mobile/features/notifications/presentation/widgets/notification_preferences_modal.dart';
import 'package:hums_mobile/previews/preview_devices.dart';
import 'package:hums_mobile/previews/preview_fakes.dart';
import 'package:hums_mobile/previews/preview_wrapper.dart';

@Preview(
  group: 'Notifications',
  name: 'Notification Inbox - Populated',
  size: PreviewDevices.phoneStandard,
)
Widget notificationInboxPopulatedPreview() {
  return previewApp(
    child: const NotificationScreen(),
  );
}

@Preview(
  group: 'Notifications',
  name: 'Notification Inbox - Empty',
  size: PreviewDevices.phoneStandard,
)
Widget notificationInboxEmptyPreview() {
  return previewApp(
    overrides: [
      notificationInboxNotifierProvider.overrideWith(
        (ref) => PreviewNotificationInboxNotifier(
          const NotificationInboxState(
            status: NotificationStatus.loaded,
            notifications: [],
            unreadCount: 0,
          ),
        ),
      ),
    ],
    child: const NotificationScreen(),
  );
}

@Preview(
  group: 'Notifications',
  name: 'Notification Inbox - Loading',
  size: PreviewDevices.phoneStandard,
)
Widget notificationInboxLoadingPreview() {
  return previewApp(
    overrides: [
      notificationInboxNotifierProvider.overrideWith(
        (ref) => PreviewNotificationInboxNotifier(
          const NotificationInboxState(status: NotificationStatus.loading),
        ),
      ),
    ],
    child: const NotificationScreen(),
  );
}

@Preview(
  group: 'Notifications',
  name: 'Notification Inbox - Error',
  size: PreviewDevices.phoneStandard,
)
Widget notificationInboxErrorPreview() {
  return previewApp(
    overrides: [
      notificationInboxNotifierProvider.overrideWith(
        (ref) => PreviewNotificationInboxNotifier(
          const NotificationInboxState(
            status: NotificationStatus.error,
            errorMessage: 'Unable to connect to notification service.',
          ),
        ),
      ),
    ],
    child: const NotificationScreen(),
  );
}

@Preview(
  group: 'Notifications',
  name: 'Notification Preferences - Sheet',
  size: PreviewDevices.phoneStandard,
)
Widget notificationPreferencesSheetPreview() {
  return previewApp(
    overrides: [
      notificationPreferencesNotifierProvider.overrideWith(
        (ref) => PreviewNotificationPreferencesNotifier(),
      ),
    ],
    child: const Scaffold(
      body: NotificationPreferencesModal(),
    ),
  );
}
