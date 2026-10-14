// pigeons/messages.dart
//
// Run codegen after any change:
//   dart run pigeon --input pigeons/messages.dart

import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/pigeon/messages.g.dart',
    kotlinOut:
        'android/app/src/main/kotlin/dev/cdenn/nearfield/pigeon/Messages.g.kt',
    kotlinOptions: KotlinOptions(package: 'dev.cdenn.nearfield.pigeon'),
    dartPackageName: 'near_field',
  ),
)
// ============ Alarms ============
class AlarmDto {
  AlarmDto({
    required this.id,
    required this.hour,
    required this.minute,
    required this.repeatDays,
    required this.enabled,
    required this.vibrate,
    required this.label,
    required this.requiredTagIds,
    required this.allowSnooze,
    required this.snoozeMinutes,
    required this.recurrenceKind,
    required this.intervalWeeks,
    required this.nthOfMonth,
    required this.weekdayOfMonth,
    required this.dayOfMonth,
    required this.anchorEpochDay,
    required this.skipDateEpochDay,
    this.soundUri,
  });

  String id;
  int hour;
  int minute;
  List<bool?> repeatDays;
  bool enabled;
  bool vibrate;
  String label;
  List<String?> requiredTagIds; // app-UUIDs; AND logic
  bool allowSnooze;
  int snoozeMinutes;

  // Recurrence rule.
  // 0 once, 1 weekly, 2 every N weeks, 3 nth weekday of month, 4 day of month.
  int recurrenceKind;
  int intervalWeeks; // kind 2; >= 1
  int nthOfMonth; // kind 3; 1..5, or -1 for last
  int weekdayOfMonth; // kind 3; 0..6, Monday-first
  int dayOfMonth; // kind 4; 1..31
  int anchorEpochDay; // kind 2 phase anchor; 0 = unset

  /// Local epoch day of a single skipped occurrence ("off for today").
  /// 0 = not skipping. The alarm stays enabled and resumes afterwards.
  int skipDateEpochDay;

  String? soundUri;
}

class SoundSelection {
  SoundSelection({required this.uri, required this.displayName});
  String uri;
  String displayName;
}

/// A sound available on the device, for the in-app browser.
class SoundItemDto {
  SoundItemDto({required this.uri, required this.title, required this.kind});
  String uri;
  String title;
  int kind; // 0 alarm, 1 notification, 2 ringtone
}

@HostApi()
abstract class AlarmHostApi {
  List<AlarmDto> getAlarms();
  void upsertAlarm(AlarmDto alarm);
  void deleteAlarm(String id);
  void setEnabled(String id, bool enabled);

  /// Skips exactly one upcoming occurrence, leaving the alarm enabled.
  /// The native side resolves which date that is.
  void skipNextOccurrence(String id);
  void clearSkipNext(String id);

  @async
  SoundSelection? pickAlarmSound();
  String? displayNameForUri(String uri);

  /// System ringtone/alarm/notification sounds. Needs no runtime permission.
  List<SoundItemDto> listSounds();
  void previewSound(String uri);
  void stopSoundPreview();
  
  /// Test vibration with the given pattern code (0=standard, 1=gentle, 2=strong, 3=heartbeat).
  void testVibration(int patternCode);
  void stopVibration();

  bool canScheduleExactAlarms();
  bool canUseFullScreenIntent();
  void openExactAlarmSettings();
  void openFullScreenIntentSettings();

  @async
  bool ensureNotificationPermission();
  void openNotificationSettings();

  String ping(String message);
}

// ============ NFC ============

class NfcTagDto {
  NfcTagDto({
    required this.uuid,
    required this.registeredAt,
    this.name,
    this.locationType,
  });
  String uuid;
  int registeredAt;
  String? name;
  String? locationType;
}

class NfcScanResult {
  NfcScanResult({
    required this.valid,
    required this.alreadyRegistered,
    this.uuid,
    this.errorMessage,
  });
  bool valid;
  bool alreadyRegistered;
  String? uuid;
  String? errorMessage;
}

@HostApi()
abstract class NfcHostApi {
  int nfcAvailability(); // 0 unsupported, 1 disabled, 2 ready
  void openNfcSettings();

  @async
  NfcTagDto beginTagRegistration(String? name, String? locationType);

  @async
  NfcScanResult beginTagScan();

  void cancelNfc();

  List<NfcTagDto> getTags();
  void deleteTag(String uuid);
  void renameTag(String uuid, String name, String? locationType);
}

// ============ Kotlin -> Flutter ============

/// Notifies the foreground app of ring lifecycle so the list refreshes.
/// state is "dismissed" | "snoozed".
@FlutterApi()
abstract class AlarmFlutterApi {
  void onAlarmStateChanged(String alarmId, String state);
}
