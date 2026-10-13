package com.example.nfcalarm.core

object AlarmConstants {
    const val CHANNEL_ID = "nfc_alarm_active"
    const val CHANNEL_NAME = "Active alarm"
    const val FOREGROUND_NOTIFICATION_ID = 42

    const val EXTRA_ALARM_ID = "extra_alarm_id"

    const val ACTION_ALARM_FIRE = "com.example.nfcalarm.ACTION_ALARM_FIRE"
    const val ACTION_DISMISS = "com.example.nfcalarm.ACTION_DISMISS"
    const val ACTION_SNOOZE = "com.example.nfcalarm.ACTION_SNOOZE"

    const val CRESCENDO_SECONDS = 30

    /** Safety cap only; the alarm rings until dismissed. */
    const val WAKELOCK_TIMEOUT_MS = 60 * 60 * 1000L
}
