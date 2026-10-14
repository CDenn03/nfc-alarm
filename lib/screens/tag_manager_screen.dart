import 'package:flutter/material.dart';

import '../models/nfc_tag.dart';
import '../providers/tag_provider.dart';
import '../theme/nothing_colors.dart';
import '../theme/nothing_typography.dart';
import '../widgets/dot_matrix_text.dart';
import '../widgets/nothing_ui.dart';
import 'tag_register_screen.dart';

/// Maps a stored location type back to its human label.
String tagLocationLabel(String? type) {
  if (type == null || type.trim().isEmpty) return 'No location';
  for (final location in kTagLocations) {
    if (location.type == type) return location.label;
  }
  return type;
}

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
            style: TextButton.styleFrom(foregroundColor: NothingColors.red),
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
        title: const Text('NFC TAGS'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: NothingCircleButton(
              icon: Icons.wifi_tethering,
              tooltip: 'Test a tag',
              onPressed: _testScan,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTag,
        icon: const Icon(Icons.add),
        label: const Text('REGISTER'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NothingGeometry.radiusMedium),
        ),
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
                        'Your tag registry could not be read.',
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

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
            children: [
              _StatusPanel(provider: provider),
              const SizedBox(height: 14),
              if (provider.tags.isEmpty)
                const _EmptyRegistry()
              else ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 2, 6, 10),
                  child: NothingSectionLabel(
                    'Registry',
                    trailing:
                        '${provider.tags.length} '
                        '${provider.tags.length == 1 ? 'tag' : 'tags'}',
                  ),
                ),
                for (final tag in provider.tags)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _TagCard(
                      tag: tag,
                      onRename: () => _rename(tag),
                      onDelete: () => _confirmDelete(tag),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.provider});

  final TagProvider provider;

  @override
  Widget build(BuildContext context) {
    final status = provider.status;
    final ready = status == NfcStatus.ready;

    final label = switch (status) {
      NfcStatus.ready => 'READY',
      NfcStatus.disabled => 'DISABLED',
      NfcStatus.unsupported => 'UNSUPPORTED',
    };
    final message = switch (status) {
      NfcStatus.ready => 'NFC is on. You can register and test tags.',
      NfcStatus.disabled =>
        'NFC is turned off. Enable it to register or scan tags.',
      NfcStatus.unsupported => 'This device has no NFC hardware.',
    };

    return NothingPanel(
      borderColor: ready ? NothingColors.outline : NothingColors.red,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: NothingSectionLabel('NFC hardware')),
              const SizedBox(width: 10),
              NothingStatusPill(
                label,
                tone: ready ? NothingTone.neutral : NothingTone.alert,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: NothingTypography.bodySmall.copyWith(
              color: NothingColors.inkMuted,
            ),
          ),
          if (status == NfcStatus.disabled) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: provider.openNfcSettings,
                child: const Text('OPEN NFC SETTINGS'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TagCard extends StatelessWidget {
  const _TagCard({
    required this.tag,
    required this.onRename,
    required this.onDelete,
  });

  final NfcTag tag;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return NothingPanel(
      color: NothingColors.ink,
      padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: NothingColors.inkMuted),
            ),
            child: const Icon(Icons.nfc, size: 18, color: NothingColors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tag.displayName,
                  style: NothingTypography.titleMedium.copyWith(
                    color: NothingColors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  tagLocationLabel(tag.locationType).toUpperCase(),
                  style: NothingTypography.labelSmall.copyWith(
                    color: NothingColors.outline,
                  ),
                ),
              ],
            ),
          ),
          NothingCircleButton(
            icon: Icons.edit_outlined,
            tooltip: 'Rename ${tag.displayName}',
            onPressed: onRename,
            onDark: true,
          ),
          const SizedBox(width: 4),
          NothingCircleButton(
            icon: Icons.delete_outline,
            tooltip: 'Delete ${tag.displayName}',
            onPressed: onDelete,
            danger: true,
          ),
        ],
      ),
    );
  }
}

class _EmptyRegistry extends StatelessWidget {
  const _EmptyRegistry();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: NothingPanel(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        child: Column(
          children: [
            const DotMatrixText(
              'NO TAGS',
              style: TextStyle(fontSize: 20, color: NothingColors.ink),
            ),
            const SizedBox(height: 18),
            Text(
              'Tap Register and hold a tag to your phone.',
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

class _ScanningDialog extends StatelessWidget {
  const _ScanningDialog({required this.onCancel});

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const NothingScanIndicator(size: 150),
          const SizedBox(height: 22),
          Text(
            'HOLD A TAG TO YOUR PHONE',
            textAlign: TextAlign.center,
            style: NothingTypography.labelLarge.copyWith(
              color: NothingColors.ink,
            ),
          ),
        ],
      ),
      actions: [TextButton(onPressed: onCancel, child: const Text('CANCEL'))],
    );
  }
}
