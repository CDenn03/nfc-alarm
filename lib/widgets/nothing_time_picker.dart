import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/clock_format.dart';
import '../theme/nothing_colors.dart';
import '../theme/nothing_typography.dart';
import 'dot_matrix_text.dart';
import 'nothing_ui.dart';

/// Rolling-digit time picker. Scrolling wheels are the default entry mode,
/// with a keyboard mode as the alternative.
Future<TimeOfDay?> showNothingTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
}) {
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TimePickerSheet(initialTime: initialTime),
  );
}

enum _EntryMode { wheel, keyboard }

class _TimePickerSheet extends StatefulWidget {
  const _TimePickerSheet({required this.initialTime});

  final TimeOfDay initialTime;

  @override
  State<_TimePickerSheet> createState() => _TimePickerSheetState();
}

class _TimePickerSheetState extends State<_TimePickerSheet> {
  static const _itemExtent = 62.0;

  late int _hour = widget.initialTime.hour;
  late int _minute = widget.initialTime.minute;
  _EntryMode _mode = _EntryMode.wheel;

  bool? _use24Hour;
  bool _formatResolved = false;

  FixedExtentScrollController? _hourController;
  FixedExtentScrollController? _minuteController;
  final _hourField = TextEditingController();
  final _minuteField = TextEditingController();

  bool get _is24Hour => _use24Hour ?? true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_formatResolved) return;
    _formatResolved = true;
    _use24Hour = use24HourFormatOf(context);
    _buildControllers();
  }

  @override
  void dispose() {
    _hourController?.dispose();
    _minuteController?.dispose();
    _hourField.dispose();
    _minuteField.dispose();
    super.dispose();
  }

  void _buildControllers() {
    _hourController?.dispose();
    _minuteController?.dispose();
    _hourController = FixedExtentScrollController(
      initialItem: _is24Hour ? _hour : hour12Of(_hour) - 1,
    );
    _minuteController = FixedExtentScrollController(initialItem: _minute);
    _syncFields();
  }

  void _syncFields() {
    _hourField.text = (_is24Hour ? _hour : hour12Of(_hour)).toString().padLeft(
      2,
      '0',
    );
    _minuteField.text = _minute.toString().padLeft(2, '0');
  }

  void _setFormat(bool use24Hour) {
    if (use24Hour == _is24Hour) return;
    setState(() {
      _use24Hour = use24Hour;
      clockFormatOverride.value = use24Hour;
      _buildControllers();
    });
  }

  void _setMode(_EntryMode mode) {
    if (mode == _mode) return;
    setState(() {
      _mode = mode;
      if (mode == _EntryMode.wheel) {
        _buildControllers();
      } else {
        _syncFields();
      }
    });
  }

  void _onHourWheel(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_is24Hour) {
        _hour = index;
      } else {
        _hour = hour24Of(index + 1, pm: isPm(_hour));
      }
    });
  }

  void _onMinuteWheel(int index) {
    HapticFeedback.selectionClick();
    setState(() => _minute = index);
  }

  void _setMeridiem({required bool pm}) {
    if (pm == isPm(_hour)) return;
    setState(() => _hour = hour24Of(hour12Of(_hour), pm: pm));
  }

  void _onHourTyped(String raw) {
    final value = int.tryParse(raw);
    if (value == null) return;
    setState(() {
      if (_is24Hour) {
        if (value < 0 || value > 23) return;
        _hour = value;
      } else {
        if (value < 1 || value > 12) return;
        _hour = hour24Of(value, pm: isPm(_hour));
      }
    });
  }

  void _onMinuteTyped(String raw) {
    final value = int.tryParse(raw);
    if (value == null || value < 0 || value > 59) return;
    setState(() => _minute = value);
  }

  @override
  Widget build(BuildContext context) {
    final digits = formatClockDigits(_hour, _minute, use24Hour: _is24Hour);
    final suffix = clockSuffix(_hour, use24Hour: _is24Hour);

    return Container(
      decoration: const BoxDecoration(
        color: NothingColors.canvas,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(NothingGeometry.radiusLarge),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: NothingColors.outlineStrong,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(child: NothingSectionLabel('Set time')),
                _SegmentToggle(
                  options: const ['24H', '12H'],
                  selectedIndex: _is24Hour ? 0 : 1,
                  onSelected: (index) => _setFormat(index == 0),
                ),
              ],
            ),
            const SizedBox(height: 20),
            NothingPanel(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      DotMatrixText(
                        digits,
                        style: const TextStyle(
                          fontSize: 44,
                          color: NothingColors.ink,
                        ),
                        semanticsLabel: formatClock(
                          _hour,
                          _minute,
                          use24Hour: _is24Hour,
                        ),
                      ),
                      if (suffix != null) ...[
                        const SizedBox(width: 10),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            suffix,
                            style: NothingTypography.labelLarge.copyWith(
                              color: NothingColors.red,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 18),
                  _SegmentToggle(
                    options: const ['WHEEL', 'TYPE'],
                    selectedIndex: _mode == _EntryMode.wheel ? 0 : 1,
                    onSelected: (index) => _setMode(
                      index == 0 ? _EntryMode.wheel : _EntryMode.keyboard,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (_mode == _EntryMode.wheel)
                    _buildWheels()
                  else
                    _buildFields(),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('CANCEL'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () =>
                        Navigator.of(context)
                            .pop(TimeOfDay(hour: _hour, minute: _minute)),
                    style: FilledButton.styleFrom(
                      backgroundColor: NothingColors.red,
                      foregroundColor: NothingColors.white,
                    ),
                    child: const Text('CONFIRM'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWheels() {
    return SizedBox(
      height: _itemExtent * 3,
      child: Stack(
        children: [
          // Selection band behind the centre row.
          Center(
            child: Container(
              height: _itemExtent,
              decoration: BoxDecoration(
                color: NothingColors.canvas,
                borderRadius: BorderRadius.circular(
                  NothingGeometry.radiusMedium,
                ),
                border: Border.all(color: NothingColors.outline),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _DigitWheel(
                  controller: _hourController!,
                  count: _is24Hour ? 24 : 12,
                  itemExtent: _itemExtent,
                  labelFor: (index) => (_is24Hour ? index : index + 1)
                      .toString()
                      .padLeft(2, '0'),
                  onChanged: _onHourWheel,
                  semanticsLabel: 'Hour',
                ),
              ),
              Text(
                ':',
                style: NothingTypography.headlineLarge.copyWith(
                  color: NothingColors.inkMuted,
                ),
              ),
              Expanded(
                child: _DigitWheel(
                  controller: _minuteController!,
                  count: 60,
                  itemExtent: _itemExtent,
                  labelFor: (index) => index.toString().padLeft(2, '0'),
                  onChanged: _onMinuteWheel,
                  semanticsLabel: 'Minute',
                ),
              ),
              if (!_is24Hour) _buildMeridiemColumn(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMeridiemColumn() {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _MeridiemButton(
            label: 'AM',
            selected: !isPm(_hour),
            onTap: () => _setMeridiem(pm: false),
          ),
          const SizedBox(height: 8),
          _MeridiemButton(
            label: 'PM',
            selected: isPm(_hour),
            onTap: () => _setMeridiem(pm: true),
          ),
        ],
      ),
    );
  }

  Widget _buildFields() {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: _TimeField(
                controller: _hourField,
                label: 'Hour',
                hint: _is24Hour ? '00-23' : '01-12',
                onChanged: _onHourTyped,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                ':',
                style: NothingTypography.headlineMedium.copyWith(
                  color: NothingColors.inkMuted,
                ),
              ),
            ),
            Expanded(
              child: _TimeField(
                controller: _minuteField,
                label: 'Minute',
                hint: '00-59',
                onChanged: _onMinuteTyped,
              ),
            ),
          ],
        ),
        if (!_is24Hour) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MeridiemButton(
                label: 'AM',
                selected: !isPm(_hour),
                onTap: () => _setMeridiem(pm: false),
              ),
              _MeridiemButton(
                label: 'PM',
                selected: isPm(_hour),
                onTap: () => _setMeridiem(pm: true),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _DigitWheel extends StatelessWidget {
  const _DigitWheel({
    required this.controller,
    required this.count,
    required this.itemExtent,
    required this.labelFor,
    required this.onChanged,
    required this.semanticsLabel,
  });

  final FixedExtentScrollController controller;
  final int count;
  final double itemExtent;
  final String Function(int index) labelFor;
  final ValueChanged<int> onChanged;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: itemExtent,
        diameterRatio: 1.6,
        perspective: 0.003,
        physics: const FixedExtentScrollPhysics(),
        // Looping gives the continuous "rolling machine" feel.
        onSelectedItemChanged: (index) =>
            onChanged(((index % count) + count) % count),
        childDelegate: ListWheelChildLoopingListDelegate(
          children: [
            for (var i = 0; i < count; i++)
              Center(
                child: Text(
                  labelFor(i),
                  style: NothingTypography.headlineLarge.copyWith(
                    fontSize: 38,
                    color: NothingColors.ink,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: 2,
      style: NothingTypography.headlineMedium,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
        fillColor: NothingColors.canvas,
      ),
    );
  }
}

class _MeridiemButton extends StatelessWidget {
  const _MeridiemButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return NothingChoicePill(label: label, selected: selected, onTap: onTap);
  }
}

class _SegmentToggle extends StatelessWidget {
  const _SegmentToggle({
    required this.options,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: NothingColors.canvas,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: NothingColors.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < options.length; i++)
            MergeSemantics(
              child: Semantics(
                selected: i == selectedIndex,
                child: Material(
                  color: i == selectedIndex
                      ? NothingColors.ink
                      : Colors.transparent,
                  clipBehavior: Clip.antiAlias,
                  shape: const StadiumBorder(),
                  child: InkWell(
                    onTap: () => onSelected(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      child: Text(
                        options[i],
                        style: NothingTypography.labelMedium.copyWith(
                          color: i == selectedIndex
                              ? NothingColors.white
                              : NothingColors.inkMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
