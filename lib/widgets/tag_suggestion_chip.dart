import 'package:flutter/material.dart';

import '../models/nfc_tag.dart';
import 'nothing_ui.dart';

class TagSuggestionChip extends StatelessWidget {
  const TagSuggestionChip({
    super.key,
    required this.location,
    required this.selected,
    required this.onTap,
  });

  final TagLocation location;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return NothingChoicePill(
      label: location.label,
      selected: selected,
      onTap: onTap,
      icon: location.type == 'custom'
          ? Icons.edit_outlined
          : Icons.place_outlined,
    );
  }
}
