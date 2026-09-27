import 'package:flutter/material.dart';

/// Standard Corner Radii for Hums
abstract class AppRadii {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double pill = 999.0;

  static const Radius rXs = Radius.circular(xs);
  static const Radius rSm = Radius.circular(sm);
  static const Radius rMd = Radius.circular(md);
  static const Radius rLg = Radius.circular(lg);
  static const Radius rXl = Radius.circular(xl);
  static const Radius rXxl = Radius.circular(xxl);
  static const Radius rPill = Radius.circular(pill);

  static const BorderRadius bXs = BorderRadius.all(rXs);
  static const BorderRadius bSm = BorderRadius.all(rSm);
  static const BorderRadius bMd = BorderRadius.all(rMd);
  static const BorderRadius bLg = BorderRadius.all(rLg);
  static const BorderRadius bXl = BorderRadius.all(rXl);
  static const BorderRadius bXxl = BorderRadius.all(rXxl);
  static const BorderRadius bPill = BorderRadius.all(rPill);
}
