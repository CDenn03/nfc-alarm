import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/nfc_tag.dart';
import '../providers/tag_provider.dart';
import '../theme/nothing_colors.dart';
import '../theme/nothing_typography.dart';
import '../widgets/nothing_ui.dart';
import '../widgets/tag_suggestion_chip.dart';

class TagRegisterScreen extends StatefulWidget {
  const TagRegisterScreen({super.key, required this.provider});

  final TagProvider provider;

  @override
  State<TagRegisterScreen> createState() => _TagRegisterScreenState();
}

class _TagRegisterScreenState extends State<TagRegisterScreen> {
  final _nameController = TextEditingController();
  String? _locationType;
  bool _scanning = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _selectLocation(TagLocation loc) {
    setState(() {
      _locationType = loc.type;
      if (loc.type != 'custom' && _nameController.text.trim().isEmpty) {
        _nameController.text = loc.label;
      }
    });
  }

  Future<void> _register() async {
    setState(() {
      _scanning = true;
      _error = null;
    });
    try {
      final tag = await widget.provider.register(
        name: _nameController.text.trim().isEmpty
            ? null
            : _nameController.text.trim(),
        locationType: _locationType,
      );
      if (mounted) Navigator.of(context).pop(tag);
    } catch (e) {
      if (!mounted) return;
      final msg = _messageFor(e);
      setState(() {
        _scanning = false;
        // A user-initiated cancel isn't an error worth showing in red.
        _error = msg == 'Cancelled.' ? null : msg;
      });
    }
  }

  String _messageFor(Object e) {
    if (e is PlatformException) return e.message ?? 'Something went wrong.';
    return e.toString();
  }

  Future<void> _cancelScan() => widget.provider.cancel();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('REGISTER TAG')),
      body: _scanning ? _buildScanning() : _buildForm(),
    );
  }

  Widget _buildForm() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      children: [
        NothingPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const NothingSectionLabel('Location'),
              const SizedBox(height: 12),
              Text(
                'Where will this tag live?',
                style: NothingTypography.bodySmall.copyWith(
                  color: NothingColors.inkMuted,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final loc in kTagLocations)
                    TagSuggestionChip(
                      location: loc,
                      selected: _locationType == loc.type,
                      onTap: () => _selectLocation(loc),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        NothingPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const NothingSectionLabel('Name'),
              const SizedBox(height: 14),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'e.g. Bathroom shelf',
                  fillColor: NothingColors.canvas,
                ),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          NothingPanel(
            borderColor: NothingColors.red,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 18,
                  color: NothingColors.red,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _error!,
                    style: NothingTypography.bodySmall.copyWith(
                      color: NothingColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 26),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _register,
            icon: const Icon(Icons.nfc, size: 18),
            label: const Text('SCAN TAG TO REGISTER'),
            style: FilledButton.styleFrom(
              backgroundColor: NothingColors.red,
              foregroundColor: NothingColors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScanning() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const NothingScanIndicator(),
            const SizedBox(height: 36),
            Text(
              'HOLD YOUR PHONE AGAINST THE TAG',
              textAlign: TextAlign.center,
              style: NothingTypography.labelLarge.copyWith(
                color: NothingColors.ink,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Keep it still until registration completes.',
              textAlign: TextAlign.center,
              style: NothingTypography.bodySmall.copyWith(
                color: NothingColors.inkMuted,
              ),
            ),
            const SizedBox(height: 36),
            OutlinedButton(onPressed: _cancelScan, child: const Text('CANCEL')),
          ],
        ),
      ),
    );
  }
}
