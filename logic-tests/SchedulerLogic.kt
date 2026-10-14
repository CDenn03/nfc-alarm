package com.example.nfcalarm.core
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.YearMonth
import java.time.temporal.TemporalAdjusters
import java.util.Calendar

data class TAlarm(
    val hour: Int,
    val minute: Int,
    val repeatDays: List<Boolean>,
    val recurrenceKind: Int = KIND_WEEKLY,
    val intervalWeeks: Int = 1,
    val nthOfMonth: Int = 1,
    val weekdayOfMonth: Int = 0,
    val dayOfMonth: Int = 1,
    val anchorEpochDay: Long = 0L
) {
    val isRecurring: Boolean
        get() = when (recurrenceKind) {
            KIND_WEEKLY, KIND_EVERY_N_WEEKS -> repeatDays.any { it }
            KIND_MONTHLY_NTH_WEEKDAY, KIND_MONTHLY_DAY_OF_MONTH -> true
            else -> false
        }

    companion object {
        const val KIND_ONCE = 0
        const val KIND_WEEKLY = 1
        const val KIND_EVERY_N_WEEKS = 2
        const val KIND_MONTHLY_NTH_WEEKDAY = 3
        const val KIND_MONTHLY_DAY_OF_MONTH = 4
        const val LAST_WEEK_OF_MONTH = -1
    }
}

object SchedulerLogic {
    private const val MONTH_HORIZON = 14

    fun mondayFirstIndex(cal: Calendar): Int = (cal.get(Calendar.DAY_OF_WEEK) + 5) % 7

    fun nextTriggerMillis(alarm: TAlarm, now: Calendar, minLeadMillis: Long = 0L): Long? {
        val threshold = now.timeInMillis + minLeadMillis
        val base = (now.clone() as Calendar).apply {
            set(Calendar.HOUR_OF_DAY, alarm.hour)
            set(Calendar.MINUTE, alarm.minute)
            set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        }
        return when (alarm.recurrenceKind) {
            TAlarm.KIND_WEEKLY -> nextWeekly(alarm, base, threshold)
            TAlarm.KIND_EVERY_N_WEEKS -> nextEveryNWeeks(alarm, base, threshold)
            TAlarm.KIND_MONTHLY_NTH_WEEKDAY -> nextMonthlyNthWeekday(alarm, base, threshold)
            TAlarm.KIND_MONTHLY_DAY_OF_MONTH -> nextMonthlyDayOfMonth(alarm, base, threshold)
            else -> nextOnce(base, threshold)
        }
    }

    private fun nextOnce(base: Calendar, threshold: Long): Long {
        val candidate = base.clone() as Calendar
        if (candidate.timeInMillis <= threshold) candidate.add(Calendar.DAY_OF_YEAR, 1)
        return candidate.timeInMillis
    }

    private fun nextWeekly(alarm: TAlarm, base: Calendar, threshold: Long): Long? {
        if (!alarm.repeatDays.any { it }) return nextOnce(base, threshold)
        for (offset in 0..7) {
            val candidate = plusDays(base, offset)
            if (candidate.timeInMillis <= threshold) continue
            if (alarm.repeatDays[mondayFirstIndex(candidate)]) return candidate.timeInMillis
        }
        return null
    }

    private fun nextEveryNWeeks(alarm: TAlarm, base: Calendar, threshold: Long): Long? {
        if (!alarm.repeatDays.any { it }) return nextOnce(base, threshold)
        val interval = alarm.intervalWeeks.coerceAtLeast(1)
        if (interval == 1) return nextWeekly(alarm, base, threshold)
        val anchorDate =
            if (alarm.anchorEpochDay > 0L) LocalDate.ofEpochDay(alarm.anchorEpochDay)
            else localDateOf(base)
        val anchorWeek = mondayEpochDay(anchorDate)
        val horizon = interval * 7 + 7
        for (offset in 0..horizon) {
            val candidate = plusDays(base, offset)
            if (candidate.timeInMillis <= threshold) continue
            if (!alarm.repeatDays[mondayFirstIndex(candidate)]) continue
            val weeksApart = (mondayEpochDay(localDateOf(candidate)) - anchorWeek) / 7
            if (Math.floorMod(weeksApart, interval.toLong()) == 0L) return candidate.timeInMillis
        }
        return null
    }

    private fun nextMonthlyNthWeekday(alarm: TAlarm, base: Calendar, threshold: Long): Long? {
        val weekday = DayOfWeek.of(alarm.weekdayOfMonth.coerceIn(0, 6) + 1)
        var month = YearMonth.from(localDateOf(base))
        repeat(MONTH_HORIZON) {
            val date = nthWeekdayOf(month, weekday, alarm.nthOfMonth)
            if (date != null) {
                val candidate = atLocalTime(date, alarm.hour, alarm.minute)
                if (candidate > threshold) return candidate
            }
            month = month.plusMonths(1)
        }
        return null
    }

    private fun nextMonthlyDayOfMonth(alarm: TAlarm, base: Calendar, threshold: Long): Long? {
        val day = alarm.dayOfMonth.coerceIn(1, 31)
        var month = YearMonth.from(localDateOf(base))
        repeat(MONTH_HORIZON) {
            if (day <= month.lengthOfMonth()) {
                val candidate = atLocalTime(month.atDay(day), alarm.hour, alarm.minute)
                if (candidate > threshold) return candidate
            }
            month = month.plusMonths(1)
        }
        return null
    }

    private fun nthWeekdayOf(month: YearMonth, weekday: DayOfWeek, nth: Int): LocalDate? {
        if (nth <= TAlarm.LAST_WEEK_OF_MONTH) {
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
}
