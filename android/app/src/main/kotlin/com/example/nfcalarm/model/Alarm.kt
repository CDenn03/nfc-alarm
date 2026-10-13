package com.example.nfcalarm.model

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
    val snoozeMinutes: Int = 5
) {
    val isRecurring: Boolean get() = repeatDays.any { it }

    init {
        require(repeatDays.size == 7) { "repeatDays must have exactly 7 entries (Mon..Sun)" }
        require(hour in 0..23) { "hour out of range: $hour" }
        require(minute in 0..59) { "minute out of range: $minute" }
    }
}
