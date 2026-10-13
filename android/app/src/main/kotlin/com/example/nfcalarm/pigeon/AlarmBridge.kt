package com.example.nfcalarm.pigeon

/**
 * Process-wide holder for the Kotlin -> Flutter Pigeon client.
 *
 * Set from MainActivity when the engine is configured. Phase 4's AlarmService
 * uses `AlarmBridge.flutterApi?.onAlarmStateChanged(...)` to push NFC tap
 * progress to the alarm UI. Null when no Flutter engine is attached (e.g. the
 * alarm fired while the app was dead) — callers must null-check.
 */
object AlarmBridge {
    @Volatile
    var flutterApi: AlarmFlutterApi? = null
}
