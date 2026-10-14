package com.example.nfcalarm.data

import android.content.Context
import com.example.nfcalarm.model.Alarm
import org.json.JSONArray
import org.json.JSONObject

/** JSON/SharedPreferences alarm store. Source of truth for scheduling. */
class AlarmStore(context: Context) {

    private val prefs =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun getAll(): List<Alarm> {
        val raw = prefs.getString(KEY, null) ?: return emptyList()
        val arr = runCatching { JSONArray(raw) }.getOrNull() ?: return emptyList()
        // Parse per-element: one corrupt row must not hide every other alarm.
        return (0 until arr.length()).mapNotNull { index ->
            runCatching { fromJson(arr.getJSONObject(index)) }.getOrNull()
        }
    }

    fun get(id: String): Alarm? = getAll().firstOrNull { it.id == id }

    fun put(alarm: Alarm) {
        val list = getAll().filter { it.id != alarm.id } + alarm
        persist(list)
    }

    fun remove(id: String) = persist(getAll().filter { it.id != id })

    private fun persist(list: List<Alarm>) {
        val arr = JSONArray()
        list.forEach { arr.put(toJson(it)) }
        prefs.edit().putString(KEY, arr.toString()).apply()
    }

    private fun toJson(a: Alarm) = JSONObject().apply {
        put("version", SCHEMA_VERSION)
        put("id", a.id)
        put("hour", a.hour)
        put("minute", a.minute)
        put("repeatDays", JSONArray(a.repeatDays))
        put("enabled", a.enabled)
        put("soundUri", a.soundUri ?: JSONObject.NULL)
        put("vibrate", a.vibrate)
        put("label", a.label)
        put("requiredTagIds", JSONArray(a.requiredTagIds))
        put("allowSnooze", a.allowSnooze)
        put("snoozeMinutes", a.snoozeMinutes)
        put("recurrenceKind", a.recurrenceKind)
        put("intervalWeeks", a.intervalWeeks)
        put("nthOfMonth", a.nthOfMonth)
        put("weekdayOfMonth", a.weekdayOfMonth)
        put("dayOfMonth", a.dayOfMonth)
        put("anchorEpochDay", a.anchorEpochDay)
        put("skipDateEpochDay", a.skipDateEpochDay)
    }

    private fun fromJson(o: JSONObject): Alarm {
        val daysArr = o.getJSONArray("repeatDays")
        val parsedDays = (0 until daysArr.length()).map { daysArr.optBoolean(it, false) }
        // Tolerate a wrong-length array rather than throwing for the whole row.
        val days = List(7) { parsedDays.getOrElse(it) { false } }
        val tags = o.optJSONArray("requiredTagIds")?.let { ja ->
            (0 until ja.length()).mapNotNull { ja.optString(it, null) }
        } ?: emptyList()

        // Legacy rows (no "recurrenceKind") are weekly, which is exactly how
        // repeatDays behaved before recurrence rules existed.
        val legacyKind = if (days.any { it }) Alarm.KIND_WEEKLY else Alarm.KIND_ONCE
        val kind = o.optInt("recurrenceKind", legacyKind)

        return Alarm(
            id = o.getString("id"),
            hour = o.getInt("hour"),
            minute = o.getInt("minute"),
            repeatDays = days,
            enabled = o.optBoolean("enabled", true),
            soundUri = if (o.isNull("soundUri")) null else o.optString("soundUri", null),
            vibrate = o.optBoolean("vibrate", true),
            label = o.optString("label", "Alarm"),
            requiredTagIds = tags,
            allowSnooze = o.optBoolean("allowSnooze", true),
            snoozeMinutes = o.optInt("snoozeMinutes", 5),
            recurrenceKind = if (kind in Alarm.KIND_ONCE..Alarm.KIND_MONTHLY_DAY_OF_MONTH) {
                kind
            } else {
                legacyKind
            },
            intervalWeeks = o.optInt("intervalWeeks", 1).coerceAtLeast(1),
            nthOfMonth = o.optInt("nthOfMonth", 1),
            weekdayOfMonth = o.optInt("weekdayOfMonth", 0).coerceIn(0, 6),
            dayOfMonth = o.optInt("dayOfMonth", 1).coerceIn(1, 31),
            anchorEpochDay = o.optLong("anchorEpochDay", 0L),
            skipDateEpochDay = o.optLong("skipDateEpochDay", 0L)
        )
    }

    private companion object {
        const val PREFS = "nfc_alarm_store"
        const val KEY = "alarms_json"

        /** 1 = original weekday-only rows, 2 = adds recurrence rules. */
        const val SCHEMA_VERSION = 2
    }
}
