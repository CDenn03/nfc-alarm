import 'package:flutter/material.dart';

import 'nothing_colors.dart';

/// Typography roles for the Nothing-inspired interface.
///
/// Deliberate constraints, applied from type-scale and readability research:
/// * Six scale steps — 12 / 14 / 16 / 20 / 28 / 44 — so adjacent levels read as
///   a genuine hierarchy instead of near-identical sizes.
/// * Two weights only, regular and bold. Intermediate weights (500/600) blur
///   the hierarchy rather than adding to it.
/// * Body text at 16, with 14 reserved for secondary copy and 12 for
///   metadata/labels. Nothing smaller carries prose.
/// * Line height 1.5+ for body, tightening towards 0.95 for display sizes.
/// * Wider tracking on uppercase, which is harder to recognise than mixed case.
///
/// Prominent dotted values use [DotMatrixText] rather than a font.
abstract final class NothingTypography {
  static const _technicalFamily = 'monospace';
  static const _bodyFamily = 'sans-serif';
  static const _tabularFigures = <FontFeature>[FontFeature.tabularFigures()];

  // Scale steps.
  static const double _caption = 12;
  static const double _label = 14;
  static const double _body = 16;
  static const double _title = 20;
  static const double _headline = 28;
  static const double _display = 44;

  static const _regular = FontWeight.w400;
  static const _bold = FontWeight.w700;

  static const displayLarge = TextStyle(
    fontFamily: _technicalFamily,
    fontSize: _display,
    height: 0.95,
    fontWeight: _regular,
    letterSpacing: -1.5,
    fontFeatures: _tabularFigures,
  );

  static const displayMedium = TextStyle(
    fontFamily: _technicalFamily,
    fontSize: _headline,
    height: 1,
    fontWeight: _regular,
    letterSpacing: -0.8,
    fontFeatures: _tabularFigures,
  );

  static const headlineLarge = TextStyle(
    fontFamily: _technicalFamily,
    fontSize: _headline,
    height: 1.1,
    fontWeight: _bold,
    letterSpacing: -0.5,
    fontFeatures: _tabularFigures,
  );

  static const headlineMedium = TextStyle(
    fontFamily: _technicalFamily,
    fontSize: _title,
    height: 1.2,
    fontWeight: _bold,
    letterSpacing: -0.2,
    fontFeatures: _tabularFigures,
  );

  static const titleLarge = TextStyle(
    fontFamily: _technicalFamily,
    fontSize: _title,
    height: 1.25,
    fontWeight: _bold,
    letterSpacing: -0.2,
    fontFeatures: _tabularFigures,
  );

  static const titleMedium = TextStyle(
    fontFamily: _bodyFamily,
    fontSize: _body,
    height: 1.3,
    fontWeight: _bold,
  );

  static const titleSmall = TextStyle(
    fontFamily: _technicalFamily,
    fontSize: _label,
    height: 1.25,
    fontWeight: _bold,
    letterSpacing: 0.4,
  );

  static const bodyLarge = TextStyle(
    fontFamily: _bodyFamily,
    fontSize: _body,
    height: 1.55,
    fontWeight: _regular,
  );

  static const bodyMedium = TextStyle(
    fontFamily: _bodyFamily,
    fontSize: _body,
    height: 1.5,
    fontWeight: _regular,
  );

  /// Secondary copy. Still a readable size — not metadata.
  static const bodySmall = TextStyle(
    fontFamily: _bodyFamily,
    fontSize: _label,
    height: 1.5,
    fontWeight: _regular,
  );

  static const labelLarge = TextStyle(
    fontFamily: _technicalFamily,
    fontSize: _label,
    height: 1.2,
    fontWeight: _bold,
    letterSpacing: 0.9,
  );

  static const labelMedium = TextStyle(
    fontFamily: _technicalFamily,
    fontSize: _caption,
    height: 1.25,
    fontWeight: _bold,
    letterSpacing: 1.1,
  );

  static const labelSmall = TextStyle(
    fontFamily: _technicalFamily,
    fontSize: _caption,
    height: 1.25,
    fontWeight: _bold,
    letterSpacing: 1.1,
  );

  static TextTheme get textTheme => const TextTheme(
    displayLarge: displayLarge,
    displayMedium: displayMedium,
    displaySmall: headlineLarge,
    headlineLarge: headlineLarge,
    headlineMedium: headlineMedium,
    headlineSmall: titleLarge,
    titleLarge: titleLarge,
    titleMedium: titleMedium,
    titleSmall: titleSmall,
    bodyLarge: bodyLarge,
    bodyMedium: bodyMedium,
    bodySmall: bodySmall,
    labelLarge: labelLarge,
    labelMedium: labelMedium,
    labelSmall: labelSmall,
  ).apply(bodyColor: NothingColors.ink, displayColor: NothingColors.ink);
}
