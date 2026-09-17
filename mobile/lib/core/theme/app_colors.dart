import 'package:flutter/material.dart';

/// Hums Centralized Color Palette
/// Designed for acoustic warmth, high contrast readability, and premium aesthetics.
abstract class AppColors {
  // Brand / Acoustic Warmth Accents
  static const Color primary = Color(0xFFE58B44); // Warm Amber / Terracotta
  static const Color primaryLight = Color(0xFFF3BA63); // Golden Brass
  static const Color primaryDark = Color(0xFFB86221); // Deep Clay

  // Backgrounds & Canvas (Audio-first dark aesthetic)
  static const Color background = Color(0xFF111113); // Deep Obsidian
  static const Color surface = Color(0xFF19191D); // Elevated Card Surface
  static const Color surfaceElevated = Color(0xFF24242A); // Dialog / Sheet Surface
  static const Color surfaceHighlight = Color(0xFF32323A); // Subtle hover / border

  // Text & Content Hierarchy
  static const Color textPrimary = Color(0xFFF6F6F8); // Pure Warm White
  static const Color textSecondary = Color(0xFFA3A3AD); // Soft Muted Gray
  static const Color textTertiary = Color(0xFF6E6E78); // Subtle Metadata / Disabled

  // Functional / Status
  static const Color success = Color(0xFF30A46C); // Sage Emerald
  static const Color error = Color(0xFFE5484D); // Crimson Coral
  static const Color warning = Color(0xFFF5A623); // Golden Amber
  static const Color info = Color(0xFF3B82F6); // Atmospheric Indigo

  // Borders & Dividers
  static const Color border = Color(0xFF2E2E36);
  static const Color divider = Color(0xFF222228);
}
