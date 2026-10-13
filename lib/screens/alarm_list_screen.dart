import 'package:flutter/material.dart';

import '../models/alarm.dart';
import '../providers/alarm_provider.dart';
import '../providers/tag_provider.dart';
import '../widgets/alarm_list_item.dart';
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
      MaterialPageRoute(
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
      MaterialPageRoute(
        builder: (_) => TagManagerScreen(provider: widget.tagProvider),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alarms'),
        actions: [
          IconButton(
            tooltip: 'NFC tags',
            onPressed: _openTags,
            icon: const Icon(Icons.nfc),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add),
      ),
      body: ListenableBuilder(
        listenable: widget.alarmProvider,
        builder: (context, _) {
          final provider = widget.alarmProvider;
          if (provider.loading && provider.alarms.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.loadError != null && provider.alarms.isEmpty) {
            return Center(
              child: FilledButton.icon(
                onPressed: provider.load,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry loading alarms'),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: provider.load,
            child: ListView(
              children: [
                if (provider.hasPermissionWarning)
                  _PermissionBanner(provider: provider),
                if (provider.alarms.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 120),
                    child: Center(
                      child: Text('No alarms yet. Tap + to add one.'),
                    ),
                  )
                else
                  for (final alarm in provider.alarms)
                    AlarmListItem(
                      alarm: alarm,
                      onTap: () => _openEditor(alarm),
                      onToggle: (enabled) =>
                          provider.setEnabled(alarm, enabled),
                    ),
                const SizedBox(height: 88),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner({required this.provider});

  final AlarmProvider provider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (message, action) in issues)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                  TextButton(onPressed: action, child: const Text('Fix')),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
