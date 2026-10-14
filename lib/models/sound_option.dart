/// Category of a device sound. Codes are the wire format shared with Kotlin.
enum SoundKind { alarm, notification, ringtone }

SoundKind soundKindFromCode(int code) =>
    (code >= 0 && code < SoundKind.values.length)
    ? SoundKind.values[code]
    : SoundKind.alarm;

String soundKindLabel(SoundKind kind) => switch (kind) {
  SoundKind.alarm => 'Alarm',
  SoundKind.notification => 'Notification',
  SoundKind.ringtone => 'Ringtone',
};

class SoundOption {
  const SoundOption({
    required this.uri,
    required this.title,
    required this.kind,
  });

  final String uri;
  final String title;
  final SoundKind kind;
}

/// Sort orders offered by the sound browser.
enum SoundSort { nameAsc, nameDesc, kind }

String soundSortLabel(SoundSort sort) => switch (sort) {
  SoundSort.nameAsc => 'A–Z',
  SoundSort.nameDesc => 'Z–A',
  SoundSort.kind => 'Type',
};
