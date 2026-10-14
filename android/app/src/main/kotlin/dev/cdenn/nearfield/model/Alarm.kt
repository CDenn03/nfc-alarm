package dev.cdenn.nearfield.model

/**
 * Full alarm model (Phase 4 adds NFC requirements + snooze config).
 *
 * [requiredTagIds] are app-UUIDs (hex). AND logic: every listed tag must be
 * tapped to dismiss. Empty => plain button dismiss.
 */
data class Alarm(
    val id: String,
    val hour: Int,
    val minute: Int,
    val repeatDays: List<Boolean> = List(7) { false },
    val enabled: Boolean = true,
    val soundUri: String? = null,
    val vibrate: Boolean = true,
    val label: String = "Alarm",
    val requiredTagIds: List<String> = emptyList(),
    val allowSnooze: Boolean = true,
    val snoozeMinutes: Int = 5,
    /** See the KIND_* constants. Defaults to weekly for legacy rows. */
    val recurrenceKind: Int = KIND_WEEKLY,
    /** Used by [KIND_EVERY_N_WEEKS]; always >= 1. */
    val intervalWeeks: Int = 1,
    /** Used by [KIND_MONTHLY_NTH_WEEKDAY]; 1..5 or [LAST_WEEK_OF_MONTH]. */
    val nthOfMonth: Int = 1,
    /** Used by [KIND_MONTHLY_NTH_WEEKDAY]; 0..6, Monday-first. */
    val weekdayOfMonth: Int = 0,
    /** Used by [KIND_MONTHLY_DAY_OF_MONTH]; 1..31. */
    val dayOfMonth: Int = 1,
    /** Phase anchor for [KIND_EVERY_N_WEEKS]; 0 means "unset". */
    val anchorEpochDay: Long = 0L,
    /**
     * Local epoch day of one skipped occurrence ("off for today"). The alarm
     * stays enabled; only the occurrence on this date is suppressed.
     */
    val skipDateEpochDay: Long = 0L
) {
    /**
     * True when the alarm should be re-armed after firing. Monthly rules are
     * always recurring; weekday-based rules need at least one day selected.
     */
    val isRecurring: Boolean
        get() = when (recurrenceKind) {
            KIND_WEEKLY, KIND_EVERY_N_WEEKS -> repeatDays.any { it }
            KIND_MONTHLY_NTH_WEEKDAY, KIND_MONTHLY_DAY_OF_MONTH -> true
            else -> false
        }

    init {
        require(repeatDays.size == 7) { "repeatDays must have exactly 7 entries (Mon..Sun)" }
        require(hour in 0..23) { "hour out of range: $hour" }
        require(minute in 0..59) { "minute out of range: $minute" }
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
