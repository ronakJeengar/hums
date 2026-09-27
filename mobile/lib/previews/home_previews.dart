import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:hums_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:hums_mobile/features/auth/presentation/states/auth_state.dart';
import 'package:hums_mobile/features/common/presentation/screens/home_screen.dart';
import 'package:hums_mobile/previews/preview_devices.dart';
import 'package:hums_mobile/previews/preview_fakes.dart';
import 'package:hums_mobile/previews/preview_wrapper.dart';

@Preview(
  group: 'Home',
  name: 'Home - Populated (Dark)',
  size: PreviewDevices.phoneStandard,
)
Widget homePopulatedPreview() {
  return previewApp(child: const HomeScreen());
}

@Preview(
  group: 'Home',
  name: 'Home - Loading',
  size: PreviewDevices.phoneStandard,
)
Widget homeLoadingPreview() {
  return previewApp(
    overrides: [
      systemHealthProvider.overrideWith(
        (ref) => Completer<Map<String, dynamic>>().future,
      ),
    ],
    child: const HomeScreen(),
  );
}

@Preview(
  group: 'Home',
  name: 'Home - Guest Mode',
  size: PreviewDevices.phoneStandard,
)
Widget homeGuestPreview() {
  return previewApp(
    overrides: [
      authNotifierProvider.overrideWith(
        (ref) => PreviewAuthNotifier(const AuthState.unauthenticated()),
      ),
    ],
    child: const HomeScreen(),
  );
}

@Preview(
  group: 'Home',
  name: 'Home - Light Theme',
  size: PreviewDevices.phoneStandard,
)
Widget homeLightPreview() {
  return previewApp(brightness: Brightness.light, child: const HomeScreen());
}

@Preview(
  group: 'Home',
  name: 'Home - Compact Phone',
  size: PreviewDevices.phoneSmall,
)
Widget homeSmallPreview() {
  return previewApp(size: PreviewDevices.phoneSmall, child: const HomeScreen());
}

@Preview(
  group: 'Home',
  name: 'Home - Large Phone',
  size: PreviewDevices.phoneLarge,
)
Widget homeLargePreview() {
  return previewApp(size: PreviewDevices.phoneLarge, child: const HomeScreen());
}
