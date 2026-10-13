# NFC Alarm

Android-only Flutter alarm clock with NFC-tag dismissal. Flutter owns alarm and tag configuration; Android owns persistence, exact scheduling, reboot recovery, and the full-screen ringing flow.

## Prerequisites

- Flutter 3.47.5 or newer (Dart 3.13.4 or newer)
- Android SDK and a physical NFC-capable Android device
- Blank NTAG215 tags for tag registration

## Setup

```bash
flutter pub get
dart run pigeon --input pigeons/messages.dart
flutter analyze
flutter run
```

Pigeon generates the typed Flutter/Android bridge at `lib/pigeon/messages.g.dart` and `android/app/src/main/kotlin/com/example/nfcalarm/pigeon/Messages.g.kt`. Re-run it whenever `pigeons/messages.dart` changes.

## Structure

- `lib/main.dart` is the composition root: it creates one `NativeChannel` and injects app-scoped alarm and tag providers.
- `lib/screens/` contains UI and local form state.
- `lib/providers/` contains `ChangeNotifier` UI state and user actions.
- `lib/services/native_channel.dart` is the sole Dart adapter over generated Pigeon APIs.
- `android/app/src/main/kotlin/com/example/nfcalarm/core/` owns alarm lifecycle and NFC operations.
- `android/app/src/main/kotlin/com/example/nfcalarm/data/` owns Android persistence.
- `pigeons/messages.dart` defines the cross-platform contract.

The app deliberately avoids a state-management or dependency-injection package. Constructor injection and `ListenableBuilder` are sufficient for this app’s small state surface.

## Validate on a device

The standalone logic harness is not a substitute for device validation. Before relying on an alarm, verify that it fires after deep sleep, survives reboot, appears over the lock screen, rejects unregistered tags, and resets tag progress after snooze. OEM battery policies can still prevent alarms without a user-granted battery-optimization exemption.
