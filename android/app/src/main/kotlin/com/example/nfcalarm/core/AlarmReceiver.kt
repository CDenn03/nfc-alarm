package com.example.nfcalarm.core

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat
import com.example.nfcalarm.data.AlarmStore

/**
 * Receives the exact-alarm broadcast, starts [AlarmService], and reschedules the
 * next occurrence for recurring alarms.
 *
 * FIX #4: the post-fire reschedule uses a 60s minimum lead so it can never land
 * back on the same minute we just fired (which would double-fire seconds later).
 */
class AlarmReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != AlarmConstants.ACTION_ALARM_FIRE) return
        val alarmId = intent.getStringExtra(AlarmConstants.EXTRA_ALARM_ID) ?: return

        val serviceIntent = Intent(context, AlarmService::class.java).apply {
            action = AlarmConstants.ACTION_ALARM_FIRE
            putExtra(AlarmConstants.EXTRA_ALARM_ID, alarmId)
        }
        ContextCompat.startForegroundService(context, serviceIntent)

        val alarm = AlarmStore(context).get(alarmId)
        if (alarm != null && alarm.isRecurring) {
            AlarmScheduler(context).schedule(alarm, minLeadMillis = 60_000L)
        }
    }
}
