import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:hums_mobile/features/profile/presentation/providers/profile_provider.dart';
import 'package:hums_mobile/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:hums_mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:hums_mobile/features/profile/presentation/states/profile_state.dart';
import 'package:hums_mobile/previews/preview_data.dart';
import 'package:hums_mobile/previews/preview_devices.dart';
import 'package:hums_mobile/previews/preview_fakes.dart';
import 'package:hums_mobile/previews/preview_wrapper.dart';

@Preview(
  group: 'Profile',
  name: 'Profile - Populated (With Avatar)',
  size: PreviewDevices.phoneStandard,
)
Widget profileLoadedPreview() {
  return previewApp(
    overrides: [
      profileNotifierProvider.overrideWith(
        (ref) => PreviewProfileNotifier(
          ProfileState.loaded(PreviewData.profileWithAvatar),
        ),
      ),
    ],
    child: const ProfileScreen(),
  );
}

@Preview(
  group: 'Profile',
  name: 'Profile - Initials Avatar',
  size: PreviewDevices.phoneStandard,
)
Widget profileInitialsPreview() {
  return previewApp(
    overrides: [
      profileNotifierProvider.overrideWith(
        (ref) =>
            PreviewProfileNotifier(ProfileState.loaded(PreviewData.profile)),
      ),
    ],
    child: const ProfileScreen(),
  );
}

@Preview(
  group: 'Profile',
  name: 'Profile - Loading State',
  size: PreviewDevices.phoneStandard,
)
Widget profileLoadingPreview() {
  return previewApp(
    overrides: [
      profileNotifierProvider.overrideWith(
        (ref) => PreviewProfileNotifier(const ProfileState.loading()),
      ),
    ],
    child: const ProfileScreen(),
  );
}

@Preview(
  group: 'Profile',
  name: 'Profile - Error State',
  size: PreviewDevices.phoneStandard,
)
Widget profileErrorPreview() {
  return previewApp(
    overrides: [
      profileNotifierProvider.overrideWith(
        (ref) => PreviewProfileNotifier(
          const ProfileState.failure(
            'Failed to load user profile. Please try again.',
          ),
        ),
      ),
    ],
    child: const ProfileScreen(),
  );
}

@Preview(
  group: 'Profile',
  name: 'Edit Profile - Form',
  size: PreviewDevices.phoneStandard,
)
Widget editProfilePreview() {
  return previewApp(child: const EditProfileScreen());
}
