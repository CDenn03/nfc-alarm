import 'package:flutter/material.dart';

/// Motion tokens.
///
/// Durations sit in the 200–300ms band that reads as "connected rather than
/// jarring", and well inside the 400ms Doherty threshold for staying in flow.
abstract final class NothingMotion {
  /// Small, high-frequency feedback (pill taps, pressed states).
  static const quick = Duration(milliseconds: 140);

  /// Default for state changes: colour, shape, and surface swaps.
  static const standard = Duration(milliseconds: 220);

  /// Entrances, route transitions, and larger layout shifts.
  static const emphasized = Duration(milliseconds: 280);

  /// Per-item offset for staggered list entrances. Ten items stay under 400ms.
  static const stagger = Duration(milliseconds: 35);

  /// Spinners are suppressed below this, since most work finishes first and a
  /// flashed spinner reads as jank.
  static const spinnerDelay = Duration(milliseconds: 300);

  static const curve = Curves.easeOutCubic;
  static const curveIn = Curves.easeInCubic;

  /// Collapses to zero when the platform asks for reduced motion.
  static Duration of(BuildContext context, [Duration duration = standard]) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}
