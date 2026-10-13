import 'package:flutter/material.dart';

import '../models/alarm.dart';

class AlarmListItem extends StatelessWidget {
  const AlarmListItem({
    super.key,
    required this.alarm,
    required this.onTap,
    required this.onToggle,
  });

  final Alarm alarm;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dim = alarm.enabled ? 1.0 : 0.4;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      title: Opacity(
        opacity: dim,
        child: Text(
          formatTime(alarm.hour, alarm.minute),
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      subtitle: Opacity(
        opacity: dim,
        child: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            [
              alarm.label,
              repeatSummary(alarm.repeatDays),
              if (!alarm.vibrate) 'No vibration',
            ].join('  ·  '),
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ),
      trailing: Switch(value: alarm.enabled, onChanged: onToggle),
    );
  }
}
