import '../models/alarm.dart';
import '../models/nfc_tag.dart';
import '../pigeon/messages.g.dart';

class NativeChannel {
  NativeChannel() : _alarm = AlarmHostApi(), _nfc = NfcHostApi();

  final AlarmHostApi _alarm;
  final NfcHostApi _nfc;

  // ---- alarms ----

  Future<List<Alarm>> getAlarms() async {
    final dtos = await _alarm.getAlarms();
    return dtos.whereType<AlarmDto>().map(_toDomainAlarm).toList();
  }

  Future<void> upsert(Alarm alarm) => _alarm.upsertAlarm(_toDtoAlarm(alarm));
  Future<void> delete(String id) => _alarm.deleteAlarm(id);
  Future<void> setEnabled(String id, bool enabled) =>
      _alarm.setEnabled(id, enabled);

  Future<(String, String)?> pickSound() async {
    final sel = await _alarm.pickAlarmSound();
    if (sel == null) return null;
    return (sel.uri, sel.displayName);
  }

  Future<String?> displayNameForUri(String uri) =>
      _alarm.displayNameForUri(uri);
  Future<bool> canScheduleExact() => _alarm.canScheduleExactAlarms();
  Future<bool> canUseFullScreenIntent() => _alarm.canUseFullScreenIntent();
  Future<void> openExactAlarmSettings() => _alarm.openExactAlarmSettings();
  Future<void> openFullScreenIntentSettings() =>
      _alarm.openFullScreenIntentSettings();
  Future<bool> ensureNotificationPermission() =>
      _alarm.ensureNotificationPermission();
  Future<void> openNotificationSettings() => _alarm.openNotificationSettings();

  // ---- nfc ----

  Future<NfcStatus> nfcAvailability() async =>
      nfcStatusFromCode(await _nfc.nfcAvailability());
  Future<void> openNfcSettings() => _nfc.openNfcSettings();

  Future<NfcTag> registerTag({String? name, String? locationType}) async =>
      _toDomainTag(await _nfc.beginTagRegistration(name, locationType));

  Future<NfcScan> scanTag() async {
    final r = await _nfc.beginTagScan();
    return NfcScan(
      valid: r.valid,
      alreadyRegistered: r.alreadyRegistered,
      uuid: r.uuid,
      errorMessage: r.errorMessage,
    );
  }

  Future<void> cancelNfc() => _nfc.cancelNfc();

  Future<List<NfcTag>> getTags() async {
    final dtos = await _nfc.getTags();
    return dtos.whereType<NfcTagDto>().map(_toDomainTag).toList();
  }

  Future<void> deleteTag(String uuid) => _nfc.deleteTag(uuid);
  Future<void> renameTag(String uuid, String name, String? locationType) =>
      _nfc.renameTag(uuid, name, locationType);

  // ---- mapping ----

  Alarm _toDomainAlarm(AlarmDto d) => Alarm(
    id: d.id,
    hour: d.hour,
    minute: d.minute,
    repeatDays: d.repeatDays.whereType<bool>().toList(),
    enabled: d.enabled,
    soundUri: d.soundUri,
    vibrate: d.vibrate,
    label: d.label,
    requiredTagIds: d.requiredTagIds.whereType<String>().toList(),
    allowSnooze: d.allowSnooze,
    snoozeMinutes: d.snoozeMinutes,
  );

  AlarmDto _toDtoAlarm(Alarm a) => AlarmDto(
    id: a.id,
    hour: a.hour,
    minute: a.minute,
    repeatDays: a.repeatDays,
    enabled: a.enabled,
    vibrate: a.vibrate,
    label: a.label,
    requiredTagIds: a.requiredTagIds,
    allowSnooze: a.allowSnooze,
    snoozeMinutes: a.snoozeMinutes,
    soundUri: a.soundUri,
  );

  NfcTag _toDomainTag(NfcTagDto d) => NfcTag(
    uuid: d.uuid,
    registeredAt: DateTime.fromMillisecondsSinceEpoch(d.registeredAt),
    name: d.name,
    locationType: d.locationType,
  );
}
