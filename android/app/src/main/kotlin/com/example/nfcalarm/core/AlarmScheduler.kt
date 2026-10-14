package com.example.nfcalarm.core

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import com.example.nfcalarm.model.Alarm
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.YearMonth
import java.time.temporal.TemporalAdjusters
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

    /**
     * First trigger strictly after `now + minLeadMillis`, or null when the rule
     * has no future occurrence (which makes [schedule] cancel the alarm).
     *
     * All candidates are built from local wall-clock fields so a 07:00 alarm
     * stays at 07:00 across DST transitions.
     */
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

        return when (alarm.recurrenceKind) {
            Alarm.KIND_WEEKLY -> nextWeekly(alarm, base, threshold)
            Alarm.KIND_EVERY_N_WEEKS -> nextEveryNWeeks(alarm, base, threshold)
            Alarm.KIND_MONTHLY_NTH_WEEKDAY -> nextMonthlyNthWeekday(alarm, base, threshold)
            Alarm.KIND_MONTHLY_DAY_OF_MONTH -> nextMonthlyDayOfMonth(alarm, base, threshold)
            else -> nextOnce(alarm, base, threshold)
        }
    }

    /** True when this candidate falls on the alarm's skipped ("off today") date. */
    private fun isSkipped(alarm: Alarm, candidate: Calendar): Boolean =
        isSkipped(alarm, localDateOf(candidate))

    private fun isSkipped(alarm: Alarm, date: LocalDate): Boolean =
        alarm.skipDateEpochDay > 0L && date.toEpochDay() == alarm.skipDateEpochDay

    private fun nextOnce(alarm: Alarm, base: Calendar, threshold: Long): Long {
        var candidate = base.clone() as Calendar
        if (candidate.timeInMillis <= threshold) candidate = plusDays(candidate, 1)
        if (isSkipped(alarm, candidate)) candidate = plusDays(candidate, 1)
        return candidate.timeInMillis
    }

    private fun nextWeekly(alarm: Alarm, base: Calendar, threshold: Long): Long? {
        if (!alarm.repeatDays.any { it }) return nextOnce(alarm, base, threshold)
        // One extra week of headroom so a skipped day can roll to the next match.
        for (offset in 0..14) {
            val candidate = plusDays(base, offset)
            if (candidate.timeInMillis <= threshold) continue
            if (!alarm.repeatDays[mondayFirstIndex(candidate)]) continue
            if (isSkipped(alarm, candidate)) continue
            return candidate.timeInMillis
        }
        return null
    }

    private fun nextEveryNWeeks(alarm: Alarm, base: Calendar, threshold: Long): Long? {
        if (!alarm.repeatDays.any { it }) return nextOnce(alarm, base, threshold)
        val interval = alarm.intervalWeeks.coerceAtLeast(1)
        if (interval == 1) return nextWeekly(alarm, base, threshold)

        // Phase is measured in whole weeks between Monday-aligned week starts.
        val anchorDate =
            if (alarm.anchorEpochDay > 0L) LocalDate.ofEpochDay(alarm.anchorEpochDay)
            else localDateOf(base)
        val anchorWeek = mondayEpochDay(anchorDate)

        val horizon = interval * 7 * 2 + 7
        for (offset in 0..horizon) {
            val candidate = plusDays(base, offset)
            if (candidate.timeInMillis <= threshold) continue
            if (!alarm.repeatDays[mondayFirstIndex(candidate)]) continue
            if (isSkipped(alarm, candidate)) continue
            val weeksApart = (mondayEpochDay(localDateOf(candidate)) - anchorWeek) / 7
            if (Math.floorMod(weeksApart, interval.toLong()) == 0L) return candidate.timeInMillis
        }
        return null
    }

    private fun nextMonthlyNthWeekday(alarm: Alarm, base: Calendar, threshold: Long): Long? {
        val weekday = DayOfWeek.of(alarm.weekdayOfMonth.coerceIn(0, 6) + 1)
        var month = YearMonth.from(localDateOf(base))
        repeat(MONTH_HORIZON) {
            val date = nthWeekdayOf(month, weekday, alarm.nthOfMonth)
            if (date != null && !isSkipped(alarm, date)) {
                val candidate = atLocalTime(date, alarm.hour, alarm.minute)
                if (candidate > threshold) return candidate
            }
            month = month.plusMonths(1)
        }
        return null
    }

    private fun nextMonthlyDayOfMonth(alarm: Alarm, base: Calendar, threshold: Long): Long? {
        val day = alarm.dayOfMonth.coerceIn(1, 31)
        var month = YearMonth.from(localDateOf(base))
        repeat(MONTH_HORIZON) {
            // Months without the requested day (e.g. the 31st in February) are skipped.
            if (day <= month.lengthOfMonth()) {
                val date = month.atDay(day)
                if (!isSkipped(alarm, date)) {
                    val candidate = atLocalTime(date, alarm.hour, alarm.minute)
                    if (candidate > threshold) return candidate
                }
            }
            month = month.plusMonths(1)
        }
        return null
    }

    /** Returns null when the month has no such occurrence (e.g. a 5th Monday). */
    private fun nthWeekdayOf(month: YearMonth, weekday: DayOfWeek, nth: Int): LocalDate? {
        if (nth <= Alarm.LAST_WEEK_OF_MONTH) {
            return month.atEndOfMonth().with(TemporalAdjusters.previousOrSame(weekday))
        }
        val first = month.atDay(1).with(TemporalAdjusters.nextOrSame(weekday))
        val candidate = first.plusWeeks((nth.coerceAtLeast(1) - 1).toLong())
        return if (YearMonth.from(candidate) == month) candidate else null
    }

    private fun atLocalTime(date: LocalDate, hour: Int, minute: Int): Long =
        Calendar.getInstance().apply {
            clear()
            set(date.year, date.monthValue - 1, date.dayOfMonth, hour, minute, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis

    private fun plusDays(base: Calendar, days: Int): Calendar =
        (base.clone() as Calendar).apply { add(Calendar.DAY_OF_YEAR, days) }

    private fun localDateOf(cal: Calendar): LocalDate = LocalDate.of(
        cal.get(Calendar.YEAR),
        cal.get(Calendar.MONTH) + 1,
        cal.get(Calendar.DAY_OF_MONTH)
    )

    private fun mondayEpochDay(date: LocalDate): Long =
        date.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY)).toEpochDay()

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

        /** Months scanned for monthly rules; covers skipped 29th–31st months. */
        const val MONTH_HORIZON = 14
    }
}
