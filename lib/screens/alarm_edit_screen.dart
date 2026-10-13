import 'package:flutter/material.dart';

import '../models/alarm.dart';
import '../models/nfc_tag.dart';
import '../providers/alarm_provider.dart';

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

class _AlarmEditScreenState extends State<AlarmEditScreen> {
  late int _hour;
  late int _minute;
  late List<bool> _repeatDays;
  late bool _vibrate;
  late TextEditingController _labelController;
  String? _soundUri;
  String _soundName = 'Default';

  late Set<String> _requiredTagIds;
  late bool _allowSnooze;
  late int _snoozeMinutes;

  List<NfcTag> _tags = const [];
  bool _tagsLoaded = false;

  @override
  void initState() {
    super.initState();
    final a = widget.alarm;
    _hour = a.hour;
    _minute = a.minute;
    _repeatDays = List<bool>.from(a.repeatDays);
    _vibrate = a.vibrate;
    _labelController = TextEditingController(text: a.label);
    _soundUri = a.soundUri;
    _requiredTagIds = a.requiredTagIds.toSet();
    _allowSnooze = a.allowSnooze;
    _snoozeMinutes = a.snoozeMinutes;
    if (_soundUri != null) {
      _soundName = 'Custom sound';
      _resolveSoundName(_soundUri!);
    }
    _loadTags();
  }

  @override
  void dispose() {
    _labelController.dispose();
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
    final picked = await showTimePicker(
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
    final result = await widget.provider.pickSound();
    if (result == null) return;
    setState(() {
      _soundUri = result.$1;
      _soundName = result.$2;
    });
  }

  void _clearSound() => setState(() {
    _soundUri = null;
    _soundName = 'Default';
  });

  void _save() {
    final alarm = widget.alarm.copyWith(
      hour: _hour,
      minute: _minute,
      repeatDays: _repeatDays,
      vibrate: _vibrate,
      label: _labelController.text.trim().isEmpty
          ? 'Alarm'
          : _labelController.text.trim(),
      soundUri: () => _soundUri,
      enabled: true,
      requiredTagIds: _requiredTagIds.toList(),
      allowSnooze: _allowSnooze,
      snoozeMinutes: _snoozeMinutes,
    );
    Navigator.of(context).pop(AlarmEditResult(alarm));
  }

  void _delete() =>
      Navigator.of(context).pop(AlarmEditResult(widget.alarm, deleted: true));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? 'New alarm' : 'Edit alarm'),
        actions: [
          if (!widget.isNew)
            IconButton(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
            ),
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Center(
            child: TextButton(
              onPressed: _pickTime,
              child: Text(
                formatTime(_hour, _minute),
                style: theme.textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < 7; i++)
                  _DayToggle(
                    label: kDayInitials[i],
                    selected: _repeatDays[i],
                    onTap: () =>
                        setState(() => _repeatDays[i] = !_repeatDays[i]),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '  ${repeatSummary(_repeatDays)}',
              style: theme.textTheme.bodySmall,
            ),
          ),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _labelController,
              decoration: const InputDecoration(
                labelText: 'Label',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ---- Required NFC tags ----
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Tags to dismiss  (all required)',
              style: theme.textTheme.titleSmall,
            ),
          ),
          _buildTagSelector(theme),

          // ---- Sound / vibrate ----
          ListTile(
            leading: const Icon(Icons.music_note),
            title: const Text('Sound'),
            subtitle: Text(_soundName),
            trailing: _soundUri == null
                ? const Icon(Icons.chevron_right)
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: _clearSound,
                  ),
            onTap: _pickSound,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.vibration),
            title: const Text('Vibrate'),
            value: _vibrate,
            onChanged: (v) => setState(() => _vibrate = v),
          ),

          // ---- Snooze ----
          SwitchListTile(
            secondary: const Icon(Icons.snooze),
            title: const Text('Allow snooze'),
            subtitle: const Text('Snoozing resets tapped-tag progress'),
            value: _allowSnooze,
            onChanged: (v) => setState(() => _allowSnooze = v),
          ),
          if (_allowSnooze)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text('Snooze length'),
                  const Spacer(),
                  DropdownButton<int>(
                    value: _snoozeMinutes,
                    items: const [5, 10, 15]
                        .map(
                          (m) =>
                              DropdownMenuItem(value: m, child: Text('$m min')),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _snoozeMinutes = v ?? 5),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTagSelector(ThemeData theme) {
    if (!_tagsLoaded) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: LinearProgressIndicator(),
      );
    }
    if (_tags.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          'No tags registered yet. Add some from the NFC tags screen, then assign them here.',
          style: theme.textTheme.bodySmall,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final tag in _tags)
            FilterChip(
              label: Text(tag.displayName),
              selected: _requiredTagIds.contains(tag.uuid),
              onSelected: (sel) => setState(() {
                if (sel) {
                  _requiredTagIds.add(tag.uuid);
                } else {
                  _requiredTagIds.remove(tag.uuid);
                }
              }),
            ),
        ],
      ),
    );
  }
}

class _DayToggle extends StatelessWidget {
  const _DayToggle({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: CircleAvatar(
        radius: 20,
        backgroundColor: selected
            ? theme.colorScheme.primary
            : theme.colorScheme.surfaceContainerHighest,
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
