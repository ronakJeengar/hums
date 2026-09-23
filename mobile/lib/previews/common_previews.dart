import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:hums_mobile/features/common/presentation/screens/error_screen.dart';
import 'package:hums_mobile/features/common/presentation/screens/splash_screen.dart';
import 'package:hums_mobile/previews/preview_devices.dart';
import 'package:hums_mobile/previews/preview_wrapper.dart';

@Preview(
  group: 'Common',
  name: 'Splash Screen',
  size: PreviewDevices.phoneStandard,
)
Widget splashPreview() {
  return previewApp(child: const SplashScreen());
}

@Preview(
  group: 'Common',
  name: 'Error Screen - Default',
  size: PreviewDevices.phoneStandard,
)
Widget errorDefaultPreview() {
  return previewApp(child: const ErrorScreen());
}

@Preview(
  group: 'Common',
  name: 'Error Screen - Custom Message',
  size: PreviewDevices.phoneStandard,
)
Widget errorCustomPreview() {
  return previewApp(
    child: const ErrorScreen(
      message:
          'The requested track or playlist could not be loaded because the server returned 404 Not Found.',
    ),
  );
}
