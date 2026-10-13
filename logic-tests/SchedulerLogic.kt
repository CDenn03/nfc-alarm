package com.example.nfcalarm.core
import java.util.Calendar

data class TAlarm(val hour: Int, val minute: Int, val repeatDays: List<Boolean>) {
    val isRecurring: Boolean get() = repeatDays.any { it }
}

object SchedulerLogic {
    fun mondayFirstIndex(cal: Calendar): Int = (cal.get(Calendar.DAY_OF_WEEK) + 5) % 7

    fun nextTriggerMillis(alarm: TAlarm, now: Calendar, minLeadMillis: Long = 0L): Long? {
        val threshold = now.timeInMillis + minLeadMillis
        val base = (now.clone() as Calendar).apply {
            set(Calendar.HOUR_OF_DAY, alarm.hour)
            set(Calendar.MINUTE, alarm.minute)
            set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
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
}
