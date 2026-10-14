import 'dart:math';

import 'recurrence.dart';

/// Vibration pattern presets
enum VibrationPattern {
  standard,
  gentle,
  urgent,
  heartbeat,
  crescendo,
  pulse,
}

String vibrationPatternLabel(VibrationPattern pattern) => switch (pattern) {
      VibrationPattern.standard => 'Standard',
      VibrationPattern.gentle => 'Gentle',
      VibrationPattern.urgent => 'Urgent',
      VibrationPattern.heartbeat => 'Heartbeat',
      VibrationPattern.crescendo => 'Crescendo',
      VibrationPattern.pulse => 'Pulse',
    };

String vibrationPatternDescription(VibrationPattern pattern) => switch (pattern) {
      VibrationPattern.standard => 'Regular intervals',
      VibrationPattern.gentle => 'Soft, slow pulses',
      VibrationPattern.urgent => 'Fast, strong bursts',
      VibrationPattern.heartbeat => 'Double-beat rhythm',
      VibrationPattern.crescendo => 'Gradually intensifying',
      VibrationPattern.pulse => 'Rhythmic waves',
    };

class Alarm {
  const Alarm({
    required this.id,
    required this.hour,
    required this.minute,
    required this.repeatDays,
    this.enabled = true,
    this.soundUri,
    this.soundVolume = 1.0,
    this.soundStartPosition = 0.0,
    this.soundEndPosition = 1.0,
    this.vibrate = true,
    this.vibrationPattern = VibrationPattern.standard,
    this.vibrationIntensity = 1.0,
    this.label = 'Alarm',
    this.requiredTagIds = const [],
    this.allowSnooze = true,
    this.snoozeMinutes = 5,
    this.recurrenceKind = RecurrenceKind.weekly,
    this.intervalWeeks = 2,
    this.nthOfMonth = 1,
    this.weekdayOfMonth = 0,
    this.dayOfMonth = 1,
    this.anchorEpochDay = 0,
    this.skipDateEpochDay = 0,
  });

  final String id;
  final int hour;
  final int minute;
  final List<bool> repeatDays; // 7 entries, Mon..Sun
  final bool enabled;
  final String? soundUri;
  final double soundVolume; // 0.0 to 1.0
  final double soundStartPosition; // 0.0 to 1.0
  final double soundEndPosition; // 0.0 to 1.0
  final bool vibrate;
  final VibrationPattern vibrationPattern;
  final double vibrationIntensity; // 0.0 to 1.0
  final String label;
  final List<String> requiredTagIds;
  final bool allowSnooze;
  final int snoozeMinutes;

  /// Recurrence rule. [repeatDays] applies to weekly and every-N-weeks.
  final RecurrenceKind recurrenceKind;
  final int intervalWeeks;
  final int nthOfMonth;
  final int weekdayOfMonth;
  final int dayOfMonth;
  final int anchorEpochDay;

  /// Local epoch day of a single skipped occurrence ("off for today").
  /// 0 means not skipping. The alarm stays enabled and resumes afterwards.
  final int skipDateEpochDay;

  bool get isRecurring => switch (recurrenceKind) {
        RecurrenceKind.once => false,
        RecurrenceKind.weekly ||
        RecurrenceKind.everyNWeeks =>
          repeatDays.any((day) => day),
        RecurrenceKind.monthlyNthWeekday ||
        RecurrenceKind.monthlyDayOfMonth =>
          true,
      };

  /// True while an upcoming occurrence is suppressed. Past skip dates are
  /// treated as expired, so this becomes false on its own.
  bool get isSkippingNext =>
      enabled && skipDateEpochDay > 0 && skipDateEpochDay >= todayEpochDay();

  /// Short state word for the UI: never relies on colour alone.
  String get stateLabel {
    if (!enabled) return 'OFF';
    if (!isSkippingNext) return 'ON';
    final delta = skipDateEpochDay - todayEpochDay();
    if (delta <= 0) return 'OFF TODAY';
    if (delta == 1) return 'OFF TOMORROW';
    final date = DateTime.fromMillisecondsSinceEpoch(
      skipDateEpochDay * Duration.millisecondsPerDay,
      isUtc: true,
    );
    return 'OFF ${kDayLabels[date.weekday - 1].toUpperCase()}';
  }

  /// Ordering rank: active, then skipped, then disabled.
  int get sortRank {
    if (!enabled) return 2;
    if (isSkippingNext) return 1;
    return 0;
  }

  int get minutesOfDay => hour * 60 + minute;

  factory Alarm.blank() => Alarm(
        id: _generateId(),
        hour: 7,
        minute: 0,
        repeatDays: List<bool>.filled(7, false),
        recurrenceKind: RecurrenceKind.once,
      );

  Alarm copyWith({
    int? hour,
    int? minute,
    List<bool>? repeatDays,
    bool? enabled,
    String? Function()? soundUri,
    double? soundVolume,
    double? soundStartPosition,
    double? soundEndPosition,
    bool? vibrate,
    VibrationPattern? vibrationPattern,
    double? vibrationIntensity,
    String? label,
    List<String>? requiredTagIds,
    bool? allowSnooze,
    int? snoozeMinutes,
    RecurrenceKind? recurrenceKind,
    int? intervalWeeks,
    int? nthOfMonth,
    int? weekdayOfMonth,
    int? dayOfMonth,
    int? anchorEpochDay,
    int? skipDateEpochDay,
  }) {
    return Alarm(
      id: id,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      repeatDays: repeatDays ?? this.repeatDays,
      enabled: enabled ?? this.enabled,
      soundUri: soundUri != null ? soundUri() : this.soundUri,
      soundVolume: soundVolume ?? this.soundVolume,
      soundStartPosition: soundStartPosition ?? this.soundStartPosition,
      soundEndPosition: soundEndPosition ?? this.soundEndPosition,
      vibrate: vibrate ?? this.vibrate,
      vibrationPattern: vibrationPattern ?? this.vibrationPattern,
      vibrationIntensity: vibrationIntensity ?? this.vibrationIntensity,
      label: label ?? this.label,
      requiredTagIds: requiredTagIds ?? this.requiredTagIds,
      allowSnooze: allowSnooze ?? this.allowSnooze,
      snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
      recurrenceKind: recurrenceKind ?? this.recurrenceKind,
      intervalWeeks: intervalWeeks ?? this.intervalWeeks,
      nthOfMonth: nthOfMonth ?? this.nthOfMonth,
      weekdayOfMonth: weekdayOfMonth ?? this.weekdayOfMonth,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      anchorEpochDay: anchorEpochDay ?? this.anchorEpochDay,
      skipDateEpochDay: skipDateEpochDay ?? this.skipDateEpochDay,
    );
  }

  static String _generateId() {
    final rand = Random();
    final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final suffix = List.generate(
      6,
      (_) => rand.nextInt(16).toRadixString(16),
    ).join();
    return '$ts-$suffix';
  }
}

const List<String> kDayLabels = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];
const List<String> kDayInitials = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

String repeatSummary(List<bool> days) {
  final on = <int>[
    for (var i = 0; i < days.length; i++)
      if (days[i]) i,
  ];
  if (on.isEmpty) return 'Once';
  if (on.length == 7) return 'Every day';
  if (on.length == 5 && on.every((i) => i < 5)) return 'Weekdays';
  if (on.length == 2 && on[0] == 5 && on[1] == 6) return 'Weekends';
  return on.map((i) => kDayLabels[i]).join(', ');
}

/// Human summary of an alarm's full recurrence rule.
String scheduleSummary(Alarm alarm) {
  switch (alarm.recurrenceKind) {
    case RecurrenceKind.once:
      return 'Once';
    case RecurrenceKind.weekly:
      return repeatSummary(alarm.repeatDays);
    case RecurrenceKind.everyNWeeks:
      if (!alarm.repeatDays.any((day) => day)) return 'Once';
      final days = repeatSummary(alarm.repeatDays);
      final every = alarm.intervalWeeks == 2
          ? 'Every 2 weeks'
          : 'Every ${alarm.intervalWeeks} weeks';
      return '$every · $days';
    case RecurrenceKind.monthlyNthWeekday:
      final nth = nthLabel(alarm.nthOfMonth);
      final day = kDayLabels[alarm.weekdayOfMonth.clamp(0, 6)];
      return '$nth $day monthly';
    case RecurrenceKind.monthlyDayOfMonth:
      return '${ordinalDay(alarm.dayOfMonth)} monthly';
  }
}

String formatTime(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

/// Local epoch day for "today", used for skip bookkeeping.
int todayEpochDay() {
  final now = DateTime.now();
  return DateTime.utc(now.year, now.month, now.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;
}
