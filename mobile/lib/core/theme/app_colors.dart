import 'package:flutter/material.dart';

/// Hums Centralized Color Palette
/// Derived from the obsidian-slate & warm-coral reference design language.
abstract class AppColors {
  // Brand & Accent Colors
  static const Color primary = Color(0xFFFF7A59); // Warm Coral / Terracotta (Play & Highlight)
  static const Color primaryLight = Color(0xFFFF9E85); // Soft Coral
  static const Color primaryDark = Color(0xFFE05B38); // Deep Terracotta
  static const Color whitePill = Color(0xFFFFFFFF); // High-contrast White for CTA Pills

  // Extended Reference Accents
  static const Color accentCoral = Color(0xFFFF7A59); // Warm Coral
  static const Color accentMint = Color(0xFF2DD4BF); // Refreshing Mint / Teal
  static const Color accentBlue = Color(0xFF60A5FA); // Sky Blue
  static const Color accentPurple = Color(0xFFA78BFA); // Soft Lavender
  static const Color accentYellow = Color(0xFFFBBF24); // Warm Gold

  // Backgrounds & Surfaces (Obsidian & Slate)
  static const Color background = Color(0xFF0D111A); // Deep Obsidian Navy Canvas
  static const Color surface = Color(0xFF151B26); // Elevated Slate Card Surface
  static const Color surfaceElevated = Color(0xFF1E2638); // Secondary Elevated Surface
  static const Color surfaceHighlight = Color(0xFF263248); // Hover / Highlight Surface
  static const Color surfaceSubtle = Color(0xFF111722); // Inset Input / Subtle Background

  // Text & Content Hierarchy
  static const Color textPrimary = Color(0xFFFFFFFF); // Crisp Pure White
  static const Color textSecondary = Color(0xFF94A3B8); // Slate Gray Subtitles & Artists
  static const Color textTertiary = Color(0xFF64748B); // Muted Slate Hints & Timestamps

  // Functional / Status
  static const Color success = Color(0xFF2DD4BF); // Mint Success
  static const Color error = Color(0xFFF43F5E); // Rose Red
  static const Color warning = Color(0xFFF59E0B); // Amber Warning
  static const Color info = Color(0xFF38BDF8); // Sky Info

  // Borders & Dividers
  static const Color border = Color(0xFF222B3D); // Subtle Slate Border
  static const Color borderSubtle = Color(0x14FFFFFF); // 8% White Border
  static const Color divider = Color(0xFF1B2332); // Divider Line
}
