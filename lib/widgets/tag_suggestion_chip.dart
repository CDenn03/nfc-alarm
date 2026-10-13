import 'package:flutter/material.dart';

import '../models/nfc_tag.dart';

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
    return ChoiceChip(
      label: Text(location.label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}
