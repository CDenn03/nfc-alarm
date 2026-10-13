package com.example.nfcalarm.core

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import com.example.nfcalarm.model.Alarm
import java.util.Calendar

class AlarmScheduler(context: Context) {

    private val appContext = context.applicationContext
    private val alarmManager =
        appContext.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    fun canScheduleExact(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) alarmManager.canScheduleExactAlarms() else true

    fun schedule(alarm: Alarm, minLeadMillis: Long = 0L) {
        if (!alarm.enabled) {
            cancel(alarm.id)
            return
        }
        val triggerAt = nextTriggerMillis(alarm, minLeadMillis = minLeadMillis) ?: run {
            cancel(alarm.id)
            return
        }
        val info = AlarmManager.AlarmClockInfo(triggerAt, showPendingIntent(alarm.id))
        alarmManager.setAlarmClock(info, firePendingIntent(alarm.id))
    }

    fun cancel(alarmId: String) {
        alarmManager.cancel(firePendingIntent(alarmId))
    }

    /**
     * Snooze re-fire of the SAME alarm after [minutes], on a separate
     * PendingIntent so it doesn't clobber the alarm's normal (recurring) schedule.
     */
    fun scheduleSnooze(alarmId: String, minutes: Int) {
        val triggerAt = System.currentTimeMillis() + minutes.coerceAtLeast(1) * 60_000L
        val info = AlarmManager.AlarmClockInfo(triggerAt, showPendingIntent(alarmId))
        alarmManager.setAlarmClock(info, firePendingIntent(alarmId, snooze = true))
    }

    fun nextTriggerMillis(
        alarm: Alarm,
        now: Calendar = Calendar.getInstance(),
        minLeadMillis: Long = 0L
    ): Long? {
        val threshold = now.timeInMillis + minLeadMillis
        val base = (now.clone() as Calendar).apply {
            set(Calendar.HOUR_OF_DAY, alarm.hour)
            set(Calendar.MINUTE, alarm.minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }

        if (!alarm.isRecurring) {
            if (base.timeInMillis <= threshold) base.add(Calendar.DAY_OF_YEAR, 1)
            return base.timeInMillis
        }

        for (offset in 0..7) {
            val candidate = (base.clone() as Calendar).apply { add(Calendar.DAY_OF_YEAR, offset) }
            if (offset == 0 && candidate.timeInMillis <= threshold) continue
            if (alarm.repeatDays[mondayFirstIndex(candidate)]) return candidate.timeInMillis
        }
        return null
    }

    private fun mondayFirstIndex(cal: Calendar): Int =
        (cal.get(Calendar.DAY_OF_WEEK) + 5) % 7

    private fun firePendingIntent(alarmId: String, snooze: Boolean = false): PendingIntent {
        val intent = Intent(appContext, AlarmReceiver::class.java).apply {
            action = AlarmConstants.ACTION_ALARM_FIRE
            putExtra(AlarmConstants.EXTRA_ALARM_ID, alarmId)
        }
        val requestCode = if (snooze) alarmId.hashCode() xor SNOOZE_SALT else alarmId.hashCode()
        return PendingIntent.getBroadcast(
            appContext, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun showPendingIntent(alarmId: String): PendingIntent {
        val launch = appContext.packageManager.getLaunchIntentForPackage(appContext.packageName)
            ?: Intent()
        return PendingIntent.getActivity(
            appContext, alarmId.hashCode() + 1, launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private companion object {
        const val SNOOZE_SALT = 0x510022
    }
}
