import 'dart:math';

class Alarm {
  const Alarm({
    required this.id,
    required this.hour,
    required this.minute,
    required this.repeatDays,
    this.enabled = true,
    this.soundUri,
    this.vibrate = true,
    this.label = 'Alarm',
    this.requiredTagIds = const [],
    this.allowSnooze = true,
    this.snoozeMinutes = 5,
  });

  final String id;
  final int hour;
  final int minute;
  final List<bool> repeatDays; // 7 entries, Mon..Sun
  final bool enabled;
  final String? soundUri;
  final bool vibrate;
  final String label;
  final List<String> requiredTagIds;
  final bool allowSnooze;
  final int snoozeMinutes;

  bool get isRecurring => repeatDays.any((d) => d);
  int get minutesOfDay => hour * 60 + minute;

  factory Alarm.blank() => Alarm(
    id: _generateId(),
    hour: 7,
    minute: 0,
    repeatDays: List<bool>.filled(7, false),
  );

  Alarm copyWith({
    int? hour,
    int? minute,
    List<bool>? repeatDays,
    bool? enabled,
    String? Function()? soundUri,
    bool? vibrate,
    String? label,
    List<String>? requiredTagIds,
    bool? allowSnooze,
    int? snoozeMinutes,
  }) {
    return Alarm(
      id: id,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      repeatDays: repeatDays ?? this.repeatDays,
      enabled: enabled ?? this.enabled,
      soundUri: soundUri != null ? soundUri() : this.soundUri,
      vibrate: vibrate ?? this.vibrate,
      label: label ?? this.label,
      requiredTagIds: requiredTagIds ?? this.requiredTagIds,
      allowSnooze: allowSnooze ?? this.allowSnooze,
      snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
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

String formatTime(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
