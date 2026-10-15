import 'package:flutter/material.dart';

import '../models/alarm.dart';
import '../providers/alarm_provider.dart';
import '../providers/tag_provider.dart';
import '../theme/nothing_colors.dart';
import '../theme/nothing_motion.dart';
import '../theme/nothing_typography.dart';
import '../widgets/alarm_list_item.dart';
import '../widgets/near_field_mark.dart';
import '../widgets/nothing_ui.dart';
import 'alarm_edit_screen.dart';
import 'tag_manager_screen.dart';

class AlarmListScreen extends StatefulWidget {
  const AlarmListScreen({
    super.key,
    required this.alarmProvider,
    required this.tagProvider,
  });

  final AlarmProvider alarmProvider;
  final TagProvider tagProvider;

  @override
  State<AlarmListScreen> createState() => _AlarmListScreenState();
}

class _AlarmListScreenState extends State<AlarmListScreen> {
  @override
  void initState() {
    super.initState();
    widget.alarmProvider.load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.alarmProvider.ensureNotificationPermission();
    });
  }

  Future<void> _openEditor([Alarm? existing]) async {
    final result = await Navigator.of(context).push<AlarmEditResult>(
      _SlidePageRoute(
        builder: (_) => AlarmEditScreen(
          provider: widget.alarmProvider,
          alarm: existing ?? Alarm.blank(),
          isNew: existing == null,
        ),
      ),
    );
    if (result == null) return;

    if (result.deleted) {
      await widget.alarmProvider.delete(result.alarm.id);
    } else {
      await widget.alarmProvider.save(result.alarm);
    }
  }

  void _openTags() {
    Navigator.of(context).push(
      _SlidePageRoute(
        builder: (_) => TagManagerScreen(provider: widget.tagProvider),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ALARMS'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: NothingCircleButton(
              icon: Icons.nfc,
              tooltip: 'NFC tags',
              onPressed: _openTags,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        tooltip: 'Add alarm',
        child: const Icon(Icons.add),
      ),
      body: ListenableBuilder(
        listenable: widget.alarmProvider,
        builder: (context, _) {
          final provider = widget.alarmProvider;
          if (provider.loading && provider.alarms.isEmpty) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              children: [
                for (var i = 0; i < 4; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: NothingEntrance(
                      index: i,
                      child: const NothingSkeletonPanel(),
                    ),
                  ),
              ],
            );
          }
          if (provider.loadError != null && provider.alarms.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: NothingPanel(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const NothingSectionLabel('Load failed'),
                      const SizedBox(height: 14),
                      Text(
                        'Your alarms could not be read from the device.',
                        style: NothingTypography.bodyMedium.copyWith(
                          color: NothingColors.inkMuted,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: provider.load,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('RETRY'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          // Group alarms by state
          final activeAlarms = provider.alarms
              .where((a) => a.enabled && !a.isSkippingNext)
              .toList();
          final pausedAlarms = provider.alarms
              .where((a) => a.enabled && a.isSkippingNext)
              .toList();
          final disabledAlarms = provider.alarms
              .where((a) => !a.enabled)
              .toList();

          return RefreshIndicator(
            color: NothingColors.red,
            backgroundColor: NothingColors.surface,
            onRefresh: provider.load,
            child: ListView(
              children: [
                if (provider.hasPermissionWarning)
                  _PermissionBanner(provider: provider),
                if (provider.alarms.isEmpty)
                  const _EmptyState()
                else ...[
                  // Active alarms section
                  if (activeAlarms.isNotEmpty) ...[
                    _SectionHeader(
                      title: 'Active',
                      count: activeAlarms.length,
                      icon: Icons.alarm_on,
                      color: NothingColors.red,
                    ),
                    _AlarmSection(
                      alarms: activeAlarms,
                      provider: provider,
                      onTap: _openEditor,
                      startIndex: 0,
                    ),
                  ],

                  // Paused alarms section
                  if (pausedAlarms.isNotEmpty) ...[
                    _SectionHeader(
                      title: 'Paused',
                      count: pausedAlarms.length,
                      icon: Icons.pause_circle_outline,
                      color: NothingColors.inkMuted,
                      subtitle: 'Skipping next occurrence',
                    ),
                    _AlarmSection(
                      alarms: pausedAlarms,
                      provider: provider,
                      onTap: _openEditor,
                      startIndex: activeAlarms.length,
                    ),
                  ],

                  // Disabled alarms section
                  if (disabledAlarms.isNotEmpty) ...[
                    _SectionHeader(
                      title: 'Disabled',
                      count: disabledAlarms.length,
                      icon: Icons.alarm_off,
                      color: NothingColors.outline,
                    ),
                    _AlarmSection(
                      alarms: disabledAlarms,
                      provider: provider,
                      onTap: _openEditor,
                      startIndex: activeAlarms.length + pausedAlarms.length,
                      muted: true,
                    ),
                  ],
                ],
                const SizedBox(height: 88),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  final String title;
  final int count;
  final IconData icon;
  final Color color;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: NothingTypography.labelMedium.copyWith(
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$count',
                        style: NothingTypography.labelSmall.copyWith(
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: NothingTypography.labelSmall.copyWith(
                      color: NothingColors.inkMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlarmSection extends StatelessWidget {
  const _AlarmSection({
    required this.alarms,
    required this.provider,
    required this.onTap,
    required this.startIndex,
    this.muted = false,
  });

  final List<Alarm> alarms;
  final AlarmProvider provider;
  final void Function(Alarm) onTap;
  final int startIndex;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < alarms.length; i++)
          NothingEntrance(
            key: ValueKey(alarms[i].id),
            index: startIndex + i,
            child: AnimatedOpacity(
              duration: NothingMotion.standard,
              opacity: muted ? 0.6 : 1.0,
              child: AlarmListItem(
                alarm: alarms[i],
                onTap: () => onTap(alarms[i]),
                onToggle: (enabled) => provider.setEnabled(alarms[i], enabled),
                onToggleSkip: (skip) => provider.setSkipNext(alarms[i], skip),
              ),
            ),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 56, 16, 0),
      child: NothingPanel(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          children: [
            const NearFieldStackedWordmark(width: 184),
            const SizedBox(height: 24),
            Text(
              'NO ALARMS YET',
              style: NothingTypography.labelLarge.copyWith(
                color: NothingColors.ink,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Tap the red button to create your first alarm.',
              textAlign: TextAlign.center,
              style: NothingTypography.bodyMedium.copyWith(
                color: NothingColors.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner({required this.provider});

  final AlarmProvider provider;

  @override
  Widget build(BuildContext context) {
    final issues = <(String, VoidCallback)>[
      if (!provider.notificationsOk)
        (
          'Notifications are off — the alarm screen and sound may not appear.',
          provider.openNotificationSettings,
        ),
      if (!provider.fullScreenIntentOk)
        (
          'Full-screen alarms are blocked — the alarm won\'t show over the lock screen.',
          provider.openFullScreenIntentSettings,
        ),
      if (!provider.exactAlarmsOk)
        (
          'Exact alarms are off — the status-bar alarm icon may not show (alarms still fire).',
          provider.openExactAlarmSettings,
        ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: NothingPanel(
        borderColor: NothingColors.red,
        padding: const EdgeInsets.fromLTRB(18, 16, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NothingSectionLabel(
              'Permissions',
              trailing: '${issues.length} to fix',
            ),
            const SizedBox(height: 12),
            for (final (message, action) in issues)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        message,
                        style: NothingTypography.bodySmall.copyWith(
                          color: NothingColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: action,
                      style: TextButton.styleFrom(
                        foregroundColor: NothingColors.red,
                      ),
                      child: const Text('FIX'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
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
          // Check for reduced motion preference
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
              opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
                ),
              ),
              child: child,
            ),
          );
        },
      );

  final WidgetBuilder builder;
}
