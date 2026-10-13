import '../pigeon/messages.g.dart';
import '../providers/alarm_provider.dart';

/// Receives dismiss/snooze notifications from the native alarm service and
/// refreshes the alarm list when the app is in the foreground.
class AlarmEvents extends AlarmFlutterApi {
  AlarmEvents(this._provider);

  final AlarmProvider _provider;

  @override
  void onAlarmStateChanged(String alarmId, String state) {
    // state is "dismissed" | "snoozed" — either way the list may have changed.
    _provider.load();
  }
}
