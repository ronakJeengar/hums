import 'package:flutter/material.dart';

/// Hums Centralized Color Palette
/// Warm Acoustic Obsidian theme:
/// True deep obsidian-black canvas (#0A0B0E), warm graphite surfaces (#14161D),
/// rich sunset amber-tangerine accents (#FF6633), and crisp white pill CTAs.
abstract class AppColors {
  // Brand & Accent Colors (Warm Sunset Amber-Tangerine)
  static const Color primary = Color(0xFFFF6633); // Vibrant Sunset Amber-Tangerine
  static const Color primaryLight = Color(0xFFFF8555); // Softer Sunset Glow
  static const Color primaryDark = Color(0xFFE54E1B); // Deep Warm Amber
  static const Color whitePill = Color(0xFFFFFFFF); // High-contrast White for CTA Pills

  // Extended Reference Accents
  static const Color accentAmber = Color(0xFFF59E0B); // Golden Amber
  static const Color accentCoral = Color(0xFFFF6633); // Warm Tangerine
  static const Color accentMint = Color(0xFF10B981); // Emerald / Mint
  static const Color accentBlue = Color(0xFF38BDF8); // Sky Blue
  static const Color accentPurple = Color(0xFFA855F7); // Soft Violet
  static const Color accentYellow = Color(0xFFFBBF24); // Warm Gold

  // Backgrounds & Surfaces (Warm Obsidian & Graphite)
  static const Color background = Color(0xFF0A0B0E); // True Deep Obsidian Canvas
  static const Color surface = Color(0xFF14161D); // Warm Graphite Card Surface
  static const Color surfaceElevated = Color(0xFF1C1F28); // Secondary Elevated Surface
  static const Color surfaceHighlight = Color(0xFF262B37); // Hover / Highlight Surface
  static const Color surfaceSubtle = Color(0xFF101217); // Inset Input / Recessed Background

  // Text & Content Hierarchy
  static const Color textPrimary = Color(0xFFFFFFFF); // Crisp Pure White
  static const Color textSecondary = Color(0xFF94A3B8); // Slate Neutral Subtitles & Artists
  static const Color textTertiary = Color(0xFF64748B); // Muted Hints & Metadata

  // Functional / Status
  static const Color success = Color(0xFF10B981); // Emerald Success
  static const Color error = Color(0xFFEF4444); // Crisp Red
  static const Color warning = Color(0xFFF59E0B); // Amber Warning
  static const Color info = Color(0xFF38BDF8); // Sky Info

  // Borders & Dividers
  static const Color border = Color(0xFF222631); // Warm Graphite Border
  static const Color borderSubtle = Color(0x1AFFFFFF); // Translucent 10% White Border
  static const Color divider = Color(0xFF1A1D26); // Subtle Graphite Divider
}
