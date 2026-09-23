import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:hums_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:hums_mobile/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:hums_mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:hums_mobile/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:hums_mobile/features/auth/presentation/screens/signup_screen.dart';
import 'package:hums_mobile/features/auth/presentation/states/auth_state.dart';
import 'package:hums_mobile/previews/preview_devices.dart';
import 'package:hums_mobile/previews/preview_fakes.dart';
import 'package:hums_mobile/previews/preview_wrapper.dart';

@Preview(
  group: 'Authentication',
  name: 'Login Screen - Default',
  size: PreviewDevices.phoneStandard,
)
Widget loginPreview() {
  return previewApp(
    overrides: [
      authNotifierProvider.overrideWith(
        (ref) => PreviewAuthNotifier(const AuthState.unauthenticated()),
      ),
    ],
    child: const LoginScreen(),
  );
}

@Preview(
  group: 'Authentication',
  name: 'Login Screen - Error State',
  size: PreviewDevices.phoneStandard,
)
Widget loginErrorPreview() {
  return previewApp(
    overrides: [
      authNotifierProvider.overrideWith(
        (ref) => PreviewAuthNotifier(
          const AuthState.failure(
            message: 'Invalid email or password combination.',
          ),
        ),
      ),
    ],
    child: const LoginScreen(),
  );
}

@Preview(
  group: 'Authentication',
  name: 'Signup Screen - Default',
  size: PreviewDevices.phoneStandard,
)
Widget signupPreview() {
  return previewApp(
    overrides: [
      authNotifierProvider.overrideWith(
        (ref) => PreviewAuthNotifier(const AuthState.unauthenticated()),
      ),
    ],
    child: const SignupScreen(),
  );
}

@Preview(
  group: 'Authentication',
  name: 'Forgot Password Screen',
  size: PreviewDevices.phoneStandard,
)
Widget forgotPasswordPreview() {
  return previewApp(
    overrides: [
      authNotifierProvider.overrideWith(
        (ref) => PreviewAuthNotifier(const AuthState.unauthenticated()),
      ),
    ],
    child: const ForgotPasswordScreen(),
  );
}

@Preview(
  group: 'Authentication',
  name: 'Reset Password Screen',
  size: PreviewDevices.phoneStandard,
)
Widget resetPasswordPreview() {
  return previewApp(
    overrides: [
      authNotifierProvider.overrideWith(
        (ref) => PreviewAuthNotifier(const AuthState.unauthenticated()),
      ),
    ],
    child: const ResetPasswordScreen(),
  );
}
