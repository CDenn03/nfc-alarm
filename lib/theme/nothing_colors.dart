import 'package:flutter/material.dart';

/// Core colors for the Nothing-inspired visual system.
abstract final class NothingColors {
  static const canvas = Color(0xFFE4E8EB);
  static const surface = Color(0xFFF8F8F6);
  static const ink = Color(0xFF181B1A);
  static const inkMuted = Color(0xFF626765);
  static const outline = Color(0xFFC7CDCF);
  static const outlineStrong = Color(0xFF929896);
  static const red = Color(0xFFD71920);

  /// Red for use on near-black surfaces. The standard red only reaches 3.3:1
  /// against [ink], which fails AA for text; this reaches ~5.2:1.
  static const redBright = Color(0xFFFF4A4F);

  static const redDark = Color(0xFFAA1117);
  static const disabled = Color(0xFFAEB4B3);
  static const white = Color(0xFFFFFFFF);
}

/// Shared geometry used by tiles and controls.
abstract final class NothingGeometry {
  static const radiusSmall = 10.0;
  static const radiusMedium = 16.0;
  static const radiusLarge = 22.0;
  static const controlHeight = 52.0;
  static const minimumTapTarget = 48.0;
}
