import 'package:flutter/material.dart';

/// Session-level override for 12/24-hour display.
///
/// `null` means "follow the device setting". This is a display preference only;
/// alarms are always stored as a 24-hour hour/minute pair. It is not persisted
/// across restarts because the app has no settings store yet.
final ValueNotifier<bool?> clockFormatOverride = ValueNotifier<bool?>(null);

bool use24HourFormatOf(BuildContext context) =>
    clockFormatOverride.value ?? MediaQuery.alwaysUse24HourFormatOf(context);

/// Converts a 24-hour value into its 12-hour display hour (1–12).
int hour12Of(int hour24) {
  final hour = hour24 % 12;
  return hour == 0 ? 12 : hour;
}

/// Rebuilds a 24-hour value from a 12-hour hour plus meridiem.
int hour24Of(int hour12, {required bool pm}) {
  final base = hour12 % 12;
  return pm ? base + 12 : base;
}

bool isPm(int hour24) => hour24 >= 12;

/// Digit-only time. Pair with [clockSuffix] when rendering 12-hour time.
String formatClockDigits(int hour, int minute, {required bool use24Hour}) {
  final displayHour = use24Hour ? hour : hour12Of(hour);
  return '${displayHour.toString().padLeft(2, '0')}'
      ':${minute.toString().padLeft(2, '0')}';
}

String? clockSuffix(int hour, {required bool use24Hour}) =>
    use24Hour ? null : (isPm(hour) ? 'PM' : 'AM');

/// Full human-readable time, used for semantics labels and plain text.
String formatClock(int hour, int minute, {required bool use24Hour}) {
  final digits = formatClockDigits(hour, minute, use24Hour: use24Hour);
  final suffix = clockSuffix(hour, use24Hour: use24Hour);
  return suffix == null ? digits : '$digits $suffix';
}
