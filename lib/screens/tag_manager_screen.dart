import 'package:flutter/material.dart';

import '../models/nfc_tag.dart';
import '../providers/tag_provider.dart';
import 'tag_register_screen.dart';

class TagManagerScreen extends StatefulWidget {
  const TagManagerScreen({super.key, required this.provider});

  final TagProvider provider;

  @override
  State<TagManagerScreen> createState() => _TagManagerScreenState();
}

class _TagManagerScreenState extends State<TagManagerScreen> {
  @override
  void initState() {
    super.initState();
    widget.provider.load();
  }

  Future<void> _addTag() async {
    if (widget.provider.status != NfcStatus.ready) {
      _showNfcOffDialog();
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TagRegisterScreen(provider: widget.provider),
      ),
    );
  }

  Future<void> _testScan() async {
    if (widget.provider.status != NfcStatus.ready) {
      _showNfcOffDialog();
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ScanningDialog(onCancel: widget.provider.cancel),
    );

    try {
      final result = await widget.provider.scan();
      if (!mounted) return;
      Navigator.of(context).pop();
      _showScanResult(result);
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not scan the NFC tag.')),
      );
    }
  }

  void _showScanResult(NfcScan result) {
    final String title;
    final String body;
    if (result.errorMessage != null) {
      title = 'Scan failed';
      body = result.errorMessage!;
    } else if (result.valid && result.alreadyRegistered) {
      final match = widget.provider.tags
          .where((tag) => tag.uuid == result.uuid)
          .toList();
      title = 'Valid tag';
      body = match.isNotEmpty
          ? 'Recognised as "${match.first.displayName}".'
          : 'Valid, and in your registry.';
    } else if (result.valid) {
      title = 'Valid tag';
      body = 'Cryptographically valid but not in your registry.';
    } else {
      title = 'Not one of your tags';
      body = 'This tag isn\'t recognised — it may be blank, a different app\'s tag, or a clone.';
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showNfcOffDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('NFC unavailable'),
        content: Text(
          widget.provider.status == NfcStatus.disabled
              ? 'NFC is turned off. Enable it to register or scan tags.'
              : 'This device has no NFC hardware.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (widget.provider.status == NfcStatus.disabled)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                widget.provider.openNfcSettings();
              },
              child: const Text('Open settings'),
            ),
        ],
      ),
    );
  }

  Future<void> _rename(NfcTag tag) async {
    final controller = TextEditingController(text: tag.name ?? '');
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename tag'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newName != null && newName.isNotEmpty) {
      await widget.provider.rename(tag.uuid, newName, tag.locationType);
    }
  }

  Future<void> _confirmDelete(NfcTag tag) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete tag?'),
        content: Text(
          '"${tag.displayName}" will be removed from your registry. '
          'The physical tag keeps its data until re-registered.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.provider.delete(tag.uuid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NFC tags'),
        actions: [
          IconButton(
            tooltip: 'Test a tag',
            onPressed: _testScan,
            icon: const Icon(Icons.wifi_tethering),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTag,
        icon: const Icon(Icons.add),
        label: const Text('Register'),
      ),
      body: ListenableBuilder(
        listenable: widget.provider,
        builder: (context, _) {
          final provider = widget.provider;
          if (provider.loading && provider.tags.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.loadError != null && provider.tags.isEmpty) {
            return Center(
              child: FilledButton.icon(
                onPressed: provider.load,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry loading tags'),
              ),
            );
          }
          if (provider.tags.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No tags registered yet.\nTap Register and hold a tag to your phone.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(
            children: [
              for (final tag in provider.tags)
                ListTile(
                  leading: const Icon(Icons.nfc),
                  title: Text(tag.displayName),
                  subtitle: Text(tag.locationType ?? 'No location'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) =>
                        value == 'rename' ? _rename(tag) : _confirmDelete(tag),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'rename', child: Text('Rename')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ScanningDialog extends StatelessWidget {
  const _ScanningDialog({required this.onCancel});

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.nfc, size: 64),
          SizedBox(height: 16),
          Text('Hold a tag to your phone…'),
          SizedBox(height: 16),
          CircularProgressIndicator(),
        ],
      ),
      actions: [TextButton(onPressed: onCancel, child: const Text('Cancel'))],
    );
  }
}
