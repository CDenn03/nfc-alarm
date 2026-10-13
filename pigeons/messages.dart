// pigeons/messages.dart
//
// Run codegen after any change:
//   dart run pigeon --input pigeons/messages.dart

import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/pigeon/messages.g.dart',
    kotlinOut:
        'android/app/src/main/kotlin/com/example/nfcalarm/pigeon/Messages.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.example.nfcalarm.pigeon'),
    dartPackageName: 'nfc_alarm',
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
  String? soundUri;
}

class SoundSelection {
  SoundSelection({required this.uri, required this.displayName});
  String uri;
  String displayName;
}

@HostApi()
abstract class AlarmHostApi {
  List<AlarmDto> getAlarms();
  void upsertAlarm(AlarmDto alarm);
  void deleteAlarm(String id);
  void setEnabled(String id, bool enabled);

  @async
  SoundSelection? pickAlarmSound();
  String? displayNameForUri(String uri);

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
