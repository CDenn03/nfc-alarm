package com.example.nfcalarm.core

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.example.nfcalarm.data.AlarmStore

/**
 * Re-registers all enabled alarms after events that wipe or invalidate pending
 * AlarmManager registrations:
 *   - reboot (alarms don't survive a reboot)
 *   - manual clock change / timezone change / DST (recompute epoch trigger)
 *
 * Handles edge cases #3 (time/timezone) from the brief.
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            "android.intent.action.QUICKBOOT_POWERON" -> rescheduleAll(context)
        }
    }

    private fun rescheduleAll(context: Context) {
        val scheduler = AlarmScheduler(context)
        AlarmStore(context).getAll()
            .filter { it.enabled }
            .forEach { scheduler.schedule(it) }
    }
}
