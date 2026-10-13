import 'package:flutter/foundation.dart';

import '../models/alarm.dart';
import '../models/nfc_tag.dart';
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
      _alarms = (results[0] as List<Alarm>)
        ..sort((a, b) => a.minutesOfDay.compareTo(b.minutesOfDay));
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
        if (item.id == alarm.id) item.copyWith(enabled: enabled) else item,
    ];
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

  Future<(String, String)?> pickSound() => _channel.pickSound();
  Future<String?> displayNameForUri(String uri) =>
      _channel.displayNameForUri(uri);

  Future<void> openExactAlarmSettings() => _channel.openExactAlarmSettings();
  Future<void> openFullScreenIntentSettings() =>
      _channel.openFullScreenIntentSettings();
  Future<void> openNotificationSettings() =>
      _channel.openNotificationSettings();
}
