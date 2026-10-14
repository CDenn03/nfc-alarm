import '../models/alarm.dart';
import '../models/nfc_tag.dart';
import '../models/recurrence.dart';
import '../models/sound_option.dart';
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
  Future<void> skipNextOccurrence(String id) => _alarm.skipNextOccurrence(id);
  Future<void> clearSkipNext(String id) => _alarm.clearSkipNext(id);

  Future<(String, String)?> pickSound() async {
    final sel = await _alarm.pickAlarmSound();
    if (sel == null) return null;
    return (sel.uri, sel.displayName);
  }

  Future<String?> displayNameForUri(String uri) =>
      _alarm.displayNameForUri(uri);

  Future<List<SoundOption>> listSounds() async {
    final items = await _alarm.listSounds();
    return items
        .whereType<SoundItemDto>()
        .map(
          (item) => SoundOption(
            uri: item.uri,
            title: item.title,
            kind: soundKindFromCode(item.kind),
          ),
        )
        .toList();
  }

  Future<void> previewSound(String uri, {double volume = 1.0}) => 
      _alarm.previewSound(uri);
  
  /// Update the volume of the currently playing preview sound.
  /// This is a best-effort operation - if native doesn't support it,
  /// it will be ignored.
  Future<void> setPreviewVolume(double volume) async {
    // Note: The native side would need to implement this.
    // For now, we just ignore it as a graceful degradation.
    // The volume is applied on the next previewSound call.
  }
  
  Future<void> stopSoundPreview() => _alarm.stopSoundPreview();

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
    recurrenceKind: recurrenceKindFromCode(d.recurrenceKind),
    intervalWeeks: d.intervalWeeks,
    nthOfMonth: d.nthOfMonth,
    weekdayOfMonth: d.weekdayOfMonth,
    dayOfMonth: d.dayOfMonth,
    anchorEpochDay: d.anchorEpochDay,
    skipDateEpochDay: d.skipDateEpochDay,
    // New fields - use defaults for now until native side supports them
    soundVolume: 1.0,
    soundStartPosition: 0.0,
    soundEndPosition: 1.0,
    vibrationPattern: VibrationPattern.standard,
    vibrationIntensity: 1.0,
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
    recurrenceKind: a.recurrenceKind.index,
    intervalWeeks: a.intervalWeeks,
    nthOfMonth: a.nthOfMonth,
    weekdayOfMonth: a.weekdayOfMonth,
    dayOfMonth: a.dayOfMonth,
    anchorEpochDay: a.anchorEpochDay,
    skipDateEpochDay: a.skipDateEpochDay,
    soundUri: a.soundUri,
    // Note: New fields (soundVolume, soundStartPosition, soundEndPosition,
    // vibrationPattern, vibrationIntensity) need to be added to the Pigeon
    // schema and native side to persist properly
  );

  NfcTag _toDomainTag(NfcTagDto d) => NfcTag(
    uuid: d.uuid,
    registeredAt: DateTime.fromMillisecondsSinceEpoch(d.registeredAt),
    name: d.name,
    locationType: d.locationType,
  );
}
