import 'dart:math';

/// Standalone RFC 4122 Version 4 UUID generator.
class UuidUtils {
  static final Random _random = Random.secure();

  static String generate() {
    final values = List<int>.generate(16, (_) => _random.nextInt(256));
    // Set version bits to 4 (0100)
    values[6] = (values[6] & 0x0f) | 0x40;
    // Set variant bits to RFC 4122 (10xx)
    values[8] = (values[8] & 0x3f) | 0x80;

    final hex = values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }
}
