import 'package:flutter/material.dart';

import '../models/alarm.dart';
import '../services/clock_format.dart';
import '../theme/nothing_colors.dart';
import '../theme/nothing_typography.dart';
import 'dot_matrix_text.dart';
import 'nothing_ui.dart';

class AlarmListItem extends StatelessWidget {
  const AlarmListItem({
    super.key,
    required this.alarm,
    required this.onTap,
    required this.onToggle,
    required this.onToggleSkip,
  });

  final Alarm alarm;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final ValueChanged<bool> onToggleSkip;

  @override
  Widget build(BuildContext context) {
    final enabled = alarm.enabled;
    final skipping = alarm.isSkippingNext;
    final use24Hour = use24HourFormatOf(context);
    final digits = formatClockDigits(
      alarm.hour,
      alarm.minute,
      use24Hour: use24Hour,
    );
    final suffix = clockSuffix(alarm.hour, use24Hour: use24Hour);
    final spokenTime = formatClock(
      alarm.hour,
      alarm.minute,
      use24Hour: use24Hour,
    );

    // Disabled alarms stay readable: state is carried by the OFF pill and the
    // outlined surface, not by low-contrast text.
    final primary = enabled ? NothingColors.white : NothingColors.inkMuted;
    final secondary = enabled ? NothingColors.outline : NothingColors.inkMuted;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: NothingPanel(
        color: enabled ? NothingColors.ink : NothingColors.surface,
        borderColor: enabled ? null : NothingColors.outline,
        onTap: onTap,
        onTapSemanticLabel: 'Edit alarm ${alarm.label} at $spokenTime',
        padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // The dot-matrix time has a fixed intrinsic width, so it
                      // scales down instead of overflowing when a wide status
                      // pill or large text scale squeezes this column.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            DotMatrixText(
                              digits,
                              style: TextStyle(fontSize: 36, color: primary),
                              semanticsLabel: spokenTime,
                            ),
                            if (suffix != null) ...[
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child: Text(
                                  suffix,
                                  style: NothingTypography.labelSmall.copyWith(
                                    color: enabled
                                        ? NothingColors.redBright
                                        : NothingColors.inkMuted,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        alarm.label,
                        style: NothingTypography.titleMedium.copyWith(
                          color: primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    NothingStatusPill(
                      alarm.stateLabel,
                      tone: !enabled
                          ? NothingTone.muted
                          : (skipping
                                ? NothingTone.neutral
                                : NothingTone.active),
                      onDark: enabled,
                    ),
                    const SizedBox(height: 6),
                    Semantics(
                      label: '${alarm.label} enabled',
                      child: Switch(value: enabled, onChanged: onToggle),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _Meta(scheduleSummary(alarm), color: secondary),
                if (alarm.requiredTagIds.isNotEmpty)
                  _Meta(
                    '${alarm.requiredTagIds.length} '
                    '${alarm.requiredTagIds.length == 1 ? 'tag' : 'tags'}',
                    color: secondary,
                    icon: Icons.nfc,
                  ),
                if (alarm.allowSnooze)
                  _Meta(
                    'snooze ${alarm.snoozeMinutes}m',
                    color: secondary,
                    icon: Icons.snooze,
                  ),
                if (!alarm.vibrate)
                  _Meta(
                    'no vibration',
                    color: secondary,
                    icon: Icons.vibration,
                  ),
                // Skipping only makes sense while the alarm is enabled.
                if (enabled)
                  _SkipChip(
                    skipping: skipping,
                    onTap: () => onToggleSkip(!skipping),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SkipChip extends StatelessWidget {
  const _SkipChip({required this.skipping, required this.onTap});

  final bool skipping;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Sits on the dark card, so it is styled for a dark background.
    final foreground = skipping ? NothingColors.white : NothingColors.outline;

    return MergeSemantics(
      child: Semantics(
        selected: skipping,
        child: Material(
          color: skipping ? NothingColors.red : Colors.transparent,
          clipBehavior: Clip.antiAlias,
          shape: StadiumBorder(
            side: BorderSide(
              color: skipping ? NothingColors.red : NothingColors.inkMuted,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            child: Tooltip(
              message: skipping
                  ? 'Turn back on for today'
                  : 'Turn off for today only',
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      skipping ? Icons.undo : Icons.bedtime_outlined,
                      size: 12,
                      color: foreground,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      skipping ? 'RESUME' : 'SKIP TODAY',
                      style: NothingTypography.labelSmall.copyWith(
                        color: foreground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.label, {required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
        ],
        Text(
          label.toUpperCase(),
          style: NothingTypography.labelSmall.copyWith(color: color),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}
