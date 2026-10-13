import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/nfc_tag.dart';
import '../providers/tag_provider.dart';
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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Register tag')),
      body: _scanning ? _buildScanning(theme) : _buildForm(theme),
    );
  }

  Widget _buildForm(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Where will this tag live?', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
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
        const SizedBox(height: 24),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'e.g. Bathroom shelf',
            border: OutlineInputBorder(),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
        ],
        const SizedBox(height: 32),
        FilledButton.icon(
          onPressed: _register,
          icon: const Icon(Icons.nfc),
          label: const Text('Scan tag to register'),
        ),
      ],
    );
  }

  Widget _buildScanning(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.nfc, size: 96, color: theme.colorScheme.primary),
          const SizedBox(height: 24),
          Text(
            'Hold your phone against the tag',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const CircularProgressIndicator(),
          const SizedBox(height: 32),
          TextButton(onPressed: _cancelScan, child: const Text('Cancel')),
        ],
      ),
    );
  }
}
