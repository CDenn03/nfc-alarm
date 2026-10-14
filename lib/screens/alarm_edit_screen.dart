import 'package:flutter/material.dart';

import '../models/alarm.dart';
import '../models/nfc_tag.dart';
import '../models/recurrence.dart';
import '../providers/alarm_provider.dart';
import '../services/clock_format.dart';
import '../theme/nothing_colors.dart';
import '../theme/nothing_motion.dart';
import '../theme/nothing_typography.dart';
import '../widgets/dot_matrix_text.dart';
import '../widgets/nothing_time_picker.dart';
import '../widgets/nothing_ui.dart';
import 'sound_picker_screen.dart';

class AlarmEditResult {
  const AlarmEditResult(this.alarm, {this.deleted = false});
  final Alarm alarm;
  final bool deleted;
}

class AlarmEditScreen extends StatefulWidget {
  const AlarmEditScreen({
    super.key,
    required this.provider,
    required this.alarm,
    required this.isNew,
  });

  final AlarmProvider provider;
  final Alarm alarm;
  final bool isNew;

  @override
  State<AlarmEditScreen> createState() => _AlarmEditScreenState();
}

class _AlarmEditScreenState extends State<AlarmEditScreen>
    with SingleTickerProviderStateMixin {
  late int _hour;
  late int _minute;
  late List<bool> _repeatDays;
  late bool _vibrate;
  late TextEditingController _labelController;
  String? _soundUri;
  String _soundName = 'Default';
  late double _soundVolume;
  late double _soundStartPosition;
  late double _soundEndPosition;

  late VibrationPattern _vibrationPattern;
  late double _vibrationIntensity;
  bool _isTestingVibration = false;

  late Set<String> _requiredTagIds;
  late bool _allowSnooze;
  late int _snoozeMinutes;

  late RecurrenceKind _recurrenceKind;
  late int _intervalWeeks;
  late int _nthOfMonth;
  late int _weekdayOfMonth;
  late int _dayOfMonth;
  late int _anchorEpochDay;

  List<NfcTag> _tags = const [];
  bool _tagsLoaded = false;

  late final AnimationController _entranceController;

  @override
  void initState() {
    super.initState();
    final a = widget.alarm;
    _hour = a.hour;
    _minute = a.minute;
    _repeatDays = List<bool>.from(a.repeatDays);
    _vibrate = a.vibrate;
    _vibrationPattern = a.vibrationPattern;
    _vibrationIntensity = a.vibrationIntensity;
    _labelController = TextEditingController(text: a.label);
    _soundUri = a.soundUri;
    _soundVolume = a.soundVolume;
    _soundStartPosition = a.soundStartPosition;
    _soundEndPosition = a.soundEndPosition;
    _requiredTagIds = a.requiredTagIds.toSet();
    _allowSnooze = a.allowSnooze;
    _snoozeMinutes = a.snoozeMinutes;
    _recurrenceKind = a.recurrenceKind;
    _intervalWeeks = a.intervalWeeks;
    _nthOfMonth = a.nthOfMonth;
    _weekdayOfMonth = a.weekdayOfMonth;
    _dayOfMonth = a.dayOfMonth;
    _anchorEpochDay = a.anchorEpochDay;

    _entranceController = AnimationController(
      vsync: this,
      duration: NothingMotion.emphasized,
    );

    if (_soundUri != null) {
      _soundName = 'Custom sound';
      _resolveSoundName(_soundUri!);
    }
    _loadTags();

    // Start entrance animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _entranceController.forward();
    });
  }

  @override
  void dispose() {
    _labelController.dispose();
    _entranceController.dispose();
    widget.provider.stopVibration();
    super.dispose();
  }

  Future<void> _loadTags() async {
    final tags = await widget.provider.availableTags();
    if (!mounted) return;
    setState(() {
      _tags = tags;
      _tagsLoaded = true;
    });
  }

  Future<void> _resolveSoundName(String uri) async {
    String? name;
    try {
      name = await widget.provider.displayNameForUri(uri);
    } catch (_) {}
    if (name != null && mounted) setState(() => _soundName = name!);
  }

  Future<void> _pickTime() async {
    final picked = await showNothingTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hour, minute: _minute),
    );
    if (picked == null) return;
    setState(() {
      _hour = picked.hour;
      _minute = picked.minute;
    });
  }

  Future<void> _pickSound() async {
    final result = await Navigator.of(context).push<SoundPickerResult>(
      _SlidePageRoute(
        builder: (_) => SoundPickerScreen(
          provider: widget.provider,
          selectedUri: _soundUri,
          initialVolume: _soundVolume,
          initialStartPosition: _soundStartPosition,
          initialEndPosition: _soundEndPosition,
        ),
      ),
    );
    if (result == null) return;
    setState(() {
      _soundUri = result.uri;
      _soundName = result.uri == null ? 'Default' : result.displayName;
      _soundVolume = result.volume;
      _soundStartPosition = result.startPosition;
      _soundEndPosition = result.endPosition;
    });
  }

  void _clearSound() => setState(() {
        _soundUri = null;
        _soundName = 'Default';
        _soundVolume = 1.0;
        _soundStartPosition = 0.0;
        _soundEndPosition = 1.0;
      });

  Future<void> _toggleVibrationTest() async {
    if (_isTestingVibration) {
      await widget.provider.stopVibration();
      if (!mounted) return;
      setState(() => _isTestingVibration = false);
    } else {
      await widget.provider.testVibration(_vibrationPattern);
      if (!mounted) return;
      setState(() => _isTestingVibration = true);
      // Auto-stop after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _isTestingVibration) {
          widget.provider.stopVibration();
          setState(() => _isTestingVibration = false);
        }
      });
    }
  }

  void _save() {
    // Every-N-weeks needs a phase anchor; anchor to today on first save.
    final anchor =
        _recurrenceKind == RecurrenceKind.everyNWeeks && _anchorEpochDay <= 0
            ? _todayEpochDay()
            : _anchorEpochDay;

    final alarm = widget.alarm.copyWith(
      hour: _hour,
      minute: _minute,
      repeatDays: _repeatDays,
      vibrate: _vibrate,
      vibrationPattern: _vibrationPattern,
      vibrationIntensity: _vibrationIntensity,
      label: _labelController.text.trim().isEmpty
          ? 'Alarm'
          : _labelController.text.trim(),
      soundUri: () => _soundUri,
      soundVolume: _soundVolume,
      soundStartPosition: _soundStartPosition,
      soundEndPosition: _soundEndPosition,
      enabled: true,
      requiredTagIds: _requiredTagIds.toList(),
      allowSnooze: _allowSnooze,
      snoozeMinutes: _snoozeMinutes,
      recurrenceKind: _recurrenceKind,
      intervalWeeks: _intervalWeeks,
      nthOfMonth: _nthOfMonth,
      weekdayOfMonth: _weekdayOfMonth,
      dayOfMonth: _dayOfMonth,
      anchorEpochDay: anchor,
    );
    Navigator.of(context).pop(AlarmEditResult(alarm));
  }

  static int _todayEpochDay() {
    final now = DateTime.now();
    return DateTime.utc(now.year, now.month, now.day).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
  }

  /// Summary of the rule as currently edited.
  String get _scheduleSummary => scheduleSummary(
        widget.alarm.copyWith(
          repeatDays: _repeatDays,
          recurrenceKind: _recurrenceKind,
          intervalWeeks: _intervalWeeks,
          nthOfMonth: _nthOfMonth,
          weekdayOfMonth: _weekdayOfMonth,
          dayOfMonth: _dayOfMonth,
        ),
      );

  void _setKind(RecurrenceKind kind) {
    setState(() {
      _recurrenceKind = kind;
      // Weekday-based rules need at least one day to be meaningful.
      if ((kind == RecurrenceKind.weekly ||
              kind == RecurrenceKind.everyNWeeks) &&
          !_repeatDays.any((day) => day)) {
        _repeatDays[DateTime.now().weekday - 1] = true;
      }
    });
  }

  void _applyPreset(List<bool> days) => setState(() {
        _repeatDays = List<bool>.from(days);
        _recurrenceKind = RecurrenceKind.weekly;
      });

  void _delete() =>
      Navigator.of(context).pop(AlarmEditResult(widget.alarm, deleted: true));

  String get _soundSummary {
    final parts = <String>[];
    parts.add(_soundName);
    if (_soundVolume < 1.0) {
      parts.add('${(_soundVolume * 100).toInt()}% vol');
    }
    if (_soundStartPosition > 0.0 || _soundEndPosition < 1.0) {
      parts.add(
          '${(_soundStartPosition * 100).toInt()}-${(_soundEndPosition * 100).toInt()}%');
    }
    return parts.join(' · ');
  }

  String get _vibrationSummary {
    if (!_vibrate) return 'Off';
    final pattern = vibrationPatternLabel(_vibrationPattern);
    if (_vibrationIntensity < 1.0) {
      return '$pattern · ${(_vibrationIntensity * 100).toInt()}%';
    }
    return pattern;
  }

  @override
  Widget build(BuildContext context) {
    final use24Hour = use24HourFormatOf(context);
    final digits = formatClockDigits(_hour, _minute, use24Hour: use24Hour);
    final suffix = clockSuffix(_hour, use24Hour: use24Hour);
    final spokenTime = formatClock(_hour, _minute, use24Hour: use24Hour);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? 'NEW ALARM' : 'EDIT ALARM'),
        actions: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 12, 8),
            child: FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                backgroundColor: NothingColors.red,
                foregroundColor: NothingColors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                minimumSize: const Size(0, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    NothingGeometry.radiusSmall,
                  ),
                ),
              ),
              child: const Text('SAVE'),
            ),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _entranceController,
        builder: (context, child) => child!,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
          children: [
            // ---- Time ----
            _AnimatedSection(
              index: 0,
              controller: _entranceController,
              child: NothingPanel(
                color: NothingColors.ink,
                onTap: _pickTime,
                onTapSemanticLabel: 'Change time, currently $spokenTime',
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NothingSectionLabel(
                      'Time',
                      onDark: true,
                      trailing: use24Hour ? '24h' : '12h',
                    ),
                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        DotMatrixText(
                          digits,
                          style: const TextStyle(
                            fontSize: 54,
                            color: NothingColors.white,
                          ),
                          semanticsLabel: spokenTime,
                        ),
                        if (suffix != null) ...[
                          const SizedBox(width: 12),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              suffix,
                              style: NothingTypography.labelLarge.copyWith(
                                color: NothingColors.redBright,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.touch_app_outlined,
                          size: 14,
                          color: NothingColors.outline,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'TAP TO CHANGE',
                          style: NothingTypography.labelSmall.copyWith(
                            color: NothingColors.outline,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ---- Repeat ----
            _AnimatedSection(
              index: 1,
              controller: _entranceController,
              child: NothingPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NothingSectionLabel('Repeat', trailing: _scheduleSummary),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final entry in const <(RecurrenceKind, String)>[
                          (RecurrenceKind.once, 'ONCE'),
                          (RecurrenceKind.weekly, 'WEEKLY'),
                          (RecurrenceKind.everyNWeeks, 'EVERY N WEEKS'),
                          (RecurrenceKind.monthlyNthWeekday, 'NTH WEEKDAY'),
                          (RecurrenceKind.monthlyDayOfMonth, 'DAY OF MONTH'),
                        ])
                          NothingChoicePill(
                            label: entry.$2,
                            selected: _recurrenceKind == entry.$1,
                            onTap: () => _setKind(entry.$1),
                          ),
                      ],
                    ),
                    ..._buildRecurrenceControls(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ---- Label ----
            _AnimatedSection(
              index: 2,
              controller: _entranceController,
              child: NothingPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const NothingSectionLabel('Label'),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _labelController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Alarm',
                        fillColor: NothingColors.canvas,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ---- Required NFC tags ----
            _AnimatedSection(
              index: 3,
              controller: _entranceController,
              child: NothingPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NothingSectionLabel(
                      'Dismiss protocol',
                      trailing: '${_requiredTagIds.length} selected',
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Every selected tag must be tapped before the alarm stops.',
                      style: NothingTypography.bodySmall.copyWith(
                        color: NothingColors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTagSelector(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ---- Sound ----
            _AnimatedSection(
              index: 4,
              controller: _entranceController,
              child: NothingPanel(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const NothingSectionLabel('Sound'),
                    const SizedBox(height: 6),
                    _SettingRow(
                      icon: Icons.music_note,
                      title: 'Tone',
                      subtitle: _soundSummary,
                      onTap: _pickSound,
                      trailing: _soundUri == null
                          ? const Icon(
                              Icons.chevron_right,
                              color: NothingColors.inkMuted,
                            )
                          : NothingCircleButton(
                              icon: Icons.close,
                              tooltip: 'Clear custom sound',
                              onPressed: _clearSound,
                            ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ---- Vibration ----
            _AnimatedSection(
              index: 5,
              controller: _entranceController,
              child: NothingPanel(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NothingSectionLabel(
                      'Vibration',
                      trailing: _vibrationSummary,
                    ),
                    const SizedBox(height: 6),
                    _SettingRow(
                      icon: Icons.vibration,
                      title: 'Vibrate',
                      subtitle: _vibrate ? 'Enabled' : 'Disabled',
                      trailing: Switch(
                        value: _vibrate,
                        onChanged: (value) => setState(() => _vibrate = value),
                      ),
                    ),
                    if (_vibrate) ...[
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        'PATTERN',
                        style: NothingTypography.labelSmall.copyWith(
                          color: NothingColors.inkMuted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final pattern in VibrationPattern.values)
                            NothingChoicePill(
                              label: vibrationPatternLabel(pattern)
                                  .toUpperCase(),
                              selected: _vibrationPattern == pattern,
                              onTap: () =>
                                  setState(() => _vibrationPattern = pattern),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        vibrationPatternDescription(_vibrationPattern),
                        style: NothingTypography.bodySmall.copyWith(
                          color: NothingColors.inkMuted,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text(
                            'INTENSITY',
                            style: NothingTypography.labelSmall.copyWith(
                              color: NothingColors.inkMuted,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 4,
                                activeTrackColor: NothingColors.red,
                                inactiveTrackColor: NothingColors.outline,
                                thumbColor: NothingColors.red,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 8,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 16,
                                ),
                              ),
                              child: Slider(
                                value: _vibrationIntensity,
                                min: 0.25,
                                max: 1.0,
                                divisions: 3,
                                onChanged: (value) =>
                                    setState(() => _vibrationIntensity = value),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 40,
                            child: Text(
                              '${(_vibrationIntensity * 100).toInt()}%',
                              style: NothingTypography.labelSmall.copyWith(
                                color: NothingColors.inkMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Test vibration button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _toggleVibrationTest,
                          icon: Icon(
                            _isTestingVibration ? Icons.stop : Icons.vibration,
                            size: 18,
                          ),
                          label: Text(
                            _isTestingVibration ? 'STOP TEST' : 'TEST VIBRATION',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _isTestingVibration 
                                ? NothingColors.red 
                                : NothingColors.ink,
                            side: BorderSide(
                              color: _isTestingVibration 
                                  ? NothingColors.red 
                                  : NothingColors.outline,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ---- Snooze ----
            _AnimatedSection(
              index: 6,
              controller: _entranceController,
              child: NothingPanel(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NothingSectionLabel(
                      'Snooze',
                      trailing: _allowSnooze ? '$_snoozeMinutes min' : 'Off',
                    ),
                    const SizedBox(height: 6),
                    _SettingRow(
                      icon: Icons.snooze,
                      title: 'Allow snooze',
                      subtitle: 'Snoozing resets tapped-tag progress',
                      trailing: Switch(
                        value: _allowSnooze,
                        onChanged: (value) =>
                            setState(() => _allowSnooze = value),
                      ),
                    ),
                    if (_allowSnooze) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final minutes in const [5, 10, 15])
                            NothingChoicePill(
                              label: '$minutes MIN',
                              selected: _snoozeMinutes == minutes,
                              onTap: () =>
                                  setState(() => _snoozeMinutes = minutes),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            _AnimatedSection(
              index: 7,
              controller: _entranceController,
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  child: Text(widget.isNew ? 'CREATE ALARM' : 'SAVE ALARM'),
                ),
              ),
            ),
            if (!widget.isNew) ...[
              const SizedBox(height: 10),
              _AnimatedSection(
                index: 8,
                controller: _entranceController,
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('DELETE ALARM'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: NothingColors.red,
                      side: const BorderSide(color: NothingColors.red),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRecurrenceControls() {
    switch (_recurrenceKind) {
      case RecurrenceKind.once:
        return [
          const SizedBox(height: 14),
          Text(
            'Rings once at the next occurrence of this time.',
            style: NothingTypography.bodySmall.copyWith(
              color: NothingColors.inkMuted,
            ),
          ),
        ];

      case RecurrenceKind.weekly:
        return [
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              NothingChoicePill(
                label: 'EVERY DAY',
                selected: _repeatDays.every((day) => day),
                onTap: () => _applyPreset(List<bool>.filled(7, true)),
              ),
              NothingChoicePill(
                label: 'WEEKDAYS',
                selected: _isPreset(const [0, 1, 2, 3, 4]),
                onTap: () => _applyPreset(const [
                  true,
                  true,
                  true,
                  true,
                  true,
                  false,
                  false,
                ]),
              ),
              NothingChoicePill(
                label: 'WEEKENDS',
                selected: _isPreset(const [5, 6]),
                onTap: () => _applyPreset(const [
                  false,
                  false,
                  false,
                  false,
                  false,
                  true,
                  true,
                ]),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _weekdayRail(),
        ];

      case RecurrenceKind.everyNWeeks:
        return [
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final weeks in kIntervalWeekOptions)
                NothingChoicePill(
                  label: '$weeks WEEKS',
                  selected: _intervalWeeks == weeks,
                  onTap: () => setState(() => _intervalWeeks = weeks),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _weekdayRail(),
          const SizedBox(height: 12),
          Text(
            'Counted from the week this alarm is saved.',
            style: NothingTypography.bodySmall.copyWith(
              color: NothingColors.inkMuted,
            ),
          ),
        ];

      case RecurrenceKind.monthlyNthWeekday:
        return [
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final nth in kNthOptions)
                NothingChoicePill(
                  label: nthLabel(nth).toUpperCase(),
                  selected: _nthOfMonth == nth,
                  onTap: () => setState(() => _nthOfMonth = nth),
                ),
            ],
          ),
          const SizedBox(height: 14),
          NothingWeekdayRail(
            selected: [for (var i = 0; i < 7; i++) i == _weekdayOfMonth],
            onToggle: (index) => setState(() => _weekdayOfMonth = index),
          ),
          const SizedBox(height: 12),
          Text(
            'Months without this occurrence are skipped.',
            style: NothingTypography.bodySmall.copyWith(
              color: NothingColors.inkMuted,
            ),
          ),
        ];

      case RecurrenceKind.monthlyDayOfMonth:
        return [
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 31,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final day = index + 1;
                return NothingChoicePill(
                  label: '$day',
                  selected: _dayOfMonth == day,
                  onTap: () => setState(() => _dayOfMonth = day),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _dayOfMonth > 28
                ? 'Months shorter than this date are skipped.'
                : 'Rings on the ${ordinalDay(_dayOfMonth)} of every month.',
            style: NothingTypography.bodySmall.copyWith(
              color: NothingColors.inkMuted,
            ),
          ),
        ];
    }
  }

  Widget _weekdayRail() => NothingWeekdayRail(
        selected: _repeatDays,
        onToggle: (index) =>
            setState(() => _repeatDays[index] = !_repeatDays[index]),
      );

  bool _isPreset(List<int> indices) {
    for (var i = 0; i < 7; i++) {
      if (_repeatDays[i] != indices.contains(i)) return false;
    }
    return true;
  }

  Widget _buildTagSelector() {
    if (!_tagsLoaded) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      );
    }
    if (_tags.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: NothingColors.canvas,
          borderRadius: BorderRadius.circular(NothingGeometry.radiusMedium),
        ),
        child: Text(
          'No tags registered yet. Add some from the NFC tags screen, then assign them here.',
          style: NothingTypography.bodySmall.copyWith(
            color: NothingColors.inkMuted,
          ),
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final tag in _tags)
          NothingChoicePill(
            label: tag.displayName,
            icon: Icons.nfc,
            selected: _requiredTagIds.contains(tag.uuid),
            onTap: () => setState(() {
              if (_requiredTagIds.contains(tag.uuid)) {
                _requiredTagIds.remove(tag.uuid);
              } else {
                _requiredTagIds.add(tag.uuid);
              }
            }),
          ),
      ],
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: NothingColors.ink),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: NothingTypography.titleMedium),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: NothingTypography.bodySmall.copyWith(
                    color: NothingColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );

    if (onTap == null) return row;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(NothingGeometry.radiusSmall),
      child: row,
    );
  }
}

/// Staggered entrance animation for each section
class _AnimatedSection extends StatelessWidget {
  const _AnimatedSection({
    required this.index,
    required this.controller,
    required this.child,
  });

  final int index;
  final AnimationController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Check for reduced motion
    if (MediaQuery.disableAnimationsOf(context)) {
      return child;
    }

    // Stagger each section's appearance
    final delay = (index * 0.08).clamp(0.0, 0.5);
    final end = (delay + 0.5).clamp(0.0, 1.0);

    final animation = CurvedAnimation(
      parent: controller,
      curve: Interval(delay, end, curve: NothingMotion.curve),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Opacity(
        opacity: animation.value,
        child: Transform.translate(
          offset: Offset(0, (1 - animation.value) * 20),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Custom slide page route with smooth animations
class _SlidePageRoute<T> extends PageRouteBuilder<T> {
  _SlidePageRoute({required this.builder})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration: NothingMotion.emphasized,
          reverseTransitionDuration: NothingMotion.standard,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            if (MediaQuery.disableAnimationsOf(context)) {
              return child;
            }

            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: NothingMotion.curve,
              reverseCurve: NothingMotion.curveIn,
            );

            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(curvedAnimation),
              child: FadeTransition(
                opacity: Tween<double>(
                  begin: 0.0,
                  end: 1.0,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
                )),
                child: child,
              ),
            );
          },
        );

  final WidgetBuilder builder;
}
