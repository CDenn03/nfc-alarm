import 'package:flutter/material.dart';

import 'pigeon/messages.g.dart';
import 'providers/alarm_provider.dart';
import 'providers/tag_provider.dart';
import 'screens/alarm_list_screen.dart';
import 'services/alarm_events.dart';
import 'services/native_channel.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final nativeChannel = NativeChannel();
  final alarmProvider = AlarmProvider(nativeChannel);
  final tagProvider = TagProvider(nativeChannel);

  AlarmFlutterApi.setUp(AlarmEvents(alarmProvider));
  runApp(NfcAlarmApp(alarmProvider: alarmProvider, tagProvider: tagProvider));
}

class NfcAlarmApp extends StatelessWidget {
  const NfcAlarmApp({
    super.key,
    required this.alarmProvider,
    required this.tagProvider,
  });

  final AlarmProvider alarmProvider;
  final TagProvider tagProvider;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NFC Alarm',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF5B6CFF),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: AlarmListScreen(
        alarmProvider: alarmProvider,
        tagProvider: tagProvider,
      ),
    );
  }
}
