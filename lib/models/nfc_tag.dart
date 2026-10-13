/// NFC availability, mapped from the native int code.
enum NfcStatus { unsupported, disabled, ready }

NfcStatus nfcStatusFromCode(int code) => switch (code) {
  2 => NfcStatus.ready,
  1 => NfcStatus.disabled,
  _ => NfcStatus.unsupported,
};

/// A registered tag (UI metadata; validity is decided cryptographically).
class NfcTag {
  const NfcTag({
    required this.uuid,
    required this.registeredAt,
    this.name,
    this.locationType,
  });

  final String uuid;
  final DateTime registeredAt;
  final String? name;
  final String? locationType;

  String get displayName =>
      (name != null && name!.trim().isNotEmpty) ? name! : 'Unnamed tag';
}

/// Result of a diagnostic scan.
class NfcScan {
  const NfcScan({
    required this.valid,
    required this.alreadyRegistered,
    this.uuid,
    this.errorMessage,
  });

  final bool valid;
  final bool alreadyRegistered;
  final String? uuid;
  final String? errorMessage;
}

/// Suggested placements shown during registration. Time-based smart suggestions
/// arrive in Phase 5; these are the static location options.
class TagLocation {
  const TagLocation(this.type, this.label);
  final String type;
  final String label;
}

const List<TagLocation> kTagLocations = [
  TagLocation('bathroom', 'Bathroom'),
  TagLocation('kitchen', 'Kitchen'),
  TagLocation('bedroom', 'Bedroom'),
  TagLocation('front_door', 'Front door'),
  TagLocation('desk', 'Desk'),
  TagLocation('custom', 'Custom'),
];
