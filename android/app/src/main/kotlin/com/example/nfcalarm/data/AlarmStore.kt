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
        val arr = JSONArray(raw)
        return (0 until arr.length()).map { fromJson(arr.getJSONObject(it)) }
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
    }

    private fun fromJson(o: JSONObject): Alarm {
        val daysArr = o.getJSONArray("repeatDays")
        val days = (0 until daysArr.length()).map { daysArr.getBoolean(it) }
        val tags = o.optJSONArray("requiredTagIds")?.let { ja ->
            (0 until ja.length()).map { ja.getString(it) }
        } ?: emptyList()
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
            snoozeMinutes = o.optInt("snoozeMinutes", 5)
        )
    }

    private companion object {
        const val PREFS = "nfc_alarm_store"
        const val KEY = "alarms_json"
    }
}
