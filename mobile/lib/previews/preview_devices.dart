import 'dart:ui';

/// Standard device profile dimensions for Flutter Widget Previews.
///
/// Provides realistic modern mobile viewport dimensions for previewing screens
/// inside IDE Widget Previewers (VS Code, Android Studio, and Flutter tooling).
abstract class PreviewDevices {
  /// Standard modern smartphone size (iPhone 15/16, Pixel 8 standard).
  /// Aspect ratio: ~19.5:9.
  static const Size phoneStandard = Size(393, 852);

  /// Compact smartphone size (Compact Android, iPhone 13 mini).
  /// Aspect ratio: ~19.5:9.
  static const Size phoneSmall = Size(360, 780);

  /// Large flagship smartphone size (iPhone 15/16 Pro Max, Pixel 8 Pro).
  /// Aspect ratio: ~19.5:9.
  static const Size phoneLarge = Size(430, 932);

  /// Default phone size used across all primary screen previews.
  static const Size defaultPhone = phoneStandard;
}
