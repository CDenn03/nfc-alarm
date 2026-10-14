import 'package:flutter/foundation.dart';

import '../models/alarm.dart';
import '../models/nfc_tag.dart';
import '../models/sound_option.dart';
import '../services/native_channel.dart';

class AlarmProvider extends ChangeNotifier {
  AlarmProvider(this._channel);

  final NativeChannel _channel;

  List<Alarm> _alarms = const [];
  List<Alarm> get alarms => _alarms;

  bool _loading = false;
  bool get loading => _loading;

  Object? _loadError;
  Object? get loadError => _loadError;

  bool exactAlarmsOk = true;
  bool fullScreenIntentOk = true;
  bool notificationsOk = true;

  bool get hasPermissionWarning =>
      !fullScreenIntentOk || !notificationsOk || !exactAlarmsOk;

  Future<void> load() async {
    _loading = true;
    _loadError = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _channel.getAlarms(),
        _channel.canScheduleExact(),
        _channel.canUseFullScreenIntent(),
      ]);
      _alarms = (results[0] as List<Alarm>)..sort(_byStateThenTime);
      exactAlarmsOk = results[1] as bool;
      fullScreenIntentOk = results[2] as bool;
    } catch (error) {
      _loadError = error;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> ensureNotificationPermission() async {
    try {
      notificationsOk = await _channel.ensureNotificationPermission();
    } catch (_) {
      notificationsOk = false;
    }
    notifyListeners();
  }

  Future<List<NfcTag>> availableTags() => _channel.getTags();

  Future<List<SoundOption>> listSounds() => _channel.listSounds();
  
  Future<void> previewSound(String uri, {double volume = 1.0}) => 
      _channel.previewSound(uri, volume: volume);
  
  Future<void> setPreviewVolume(double volume) => 
      _channel.setPreviewVolume(volume);
  
  Future<void> stopSoundPreview() => _channel.stopSoundPreview();

  Future<void> save(Alarm alarm) async {
    await _channel.upsert(alarm);
    await load();
  }

  Future<void> delete(String id) async {
    await _channel.delete(id);
    await load();
  }

  Future<void> setEnabled(Alarm alarm, bool enabled) async {
    final previousAlarms = _alarms;
    _alarms = [
      for (final item in _alarms)
        if (item.id == alarm.id)
          // Re-enabling also clears a pending skip, matching the native side.
          item.copyWith(
            enabled: enabled,
            skipDateEpochDay: enabled ? 0 : item.skipDateEpochDay,
          )
        else
          item,
    ]..sort(_byStateThenTime);
    notifyListeners();

    try {
      await _channel.setEnabled(alarm.id, enabled);
    } catch (_) {
      _alarms = previousAlarms;
      notifyListeners();
      rethrow;
    }

    await load();
  }

  /// Turns an alarm off for its next occurrence only, leaving it enabled.
  Future<void> setSkipNext(Alarm alarm, bool skip) async {
    final previousAlarms = _alarms;
    // Optimistic: the authoritative skip date comes back from load().
    _alarms = [
      for (final item in _alarms)
        if (item.id == alarm.id)
          item.copyWith(skipDateEpochDay: skip ? todayEpochDay() : 0)
        else
          item,
    ]..sort(_byStateThenTime);
    notifyListeners();

    try {
      if (skip) {
        await _channel.skipNextOccurrence(alarm.id);
      } else {
        await _channel.clearSkipNext(alarm.id);
      }
    } catch (_) {
      _alarms = previousAlarms;
      notifyListeners();
      rethrow;
    }

    await load();
  }

  /// Active alarms first, then those off for a day, then disabled ones.
  static int _byStateThenTime(Alarm a, Alarm b) {
    final byState = a.sortRank.compareTo(b.sortRank);
    if (byState != 0) return byState;
    return a.minutesOfDay.compareTo(b.minutesOfDay);
  }

  Future<(String, String)?> pickSound() => _channel.pickSound();
  Future<String?> displayNameForUri(String uri) =>
      _channel.displayNameForUri(uri);

  Future<void> openExactAlarmSettings() => _channel.openExactAlarmSettings();
  Future<void> openFullScreenIntentSettings() =>
      _channel.openFullScreenIntentSettings();
  Future<void> openNotificationSettings() =>
      _channel.openNotificationSettings();
}
