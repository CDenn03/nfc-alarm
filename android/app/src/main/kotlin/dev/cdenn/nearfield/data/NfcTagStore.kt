package dev.cdenn.nearfield.data

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/** A registered tag: its app-UUID plus friendly metadata for the UI. */
data class NfcTagRecord(
    val uuid: String,
    val name: String?,
    val locationType: String?,
    val registeredAt: Long
)

/**
 * Registry of paired tags. JSON/SharedPreferences to match [AlarmStore] and keep
 * the build dependency-free. Swap for the Room `NfcTagRepository` (see the
 * optional-room drop-in) if you want typed queries — the method surface matches.
 *
 * Note: this is UI metadata only. Tag *validity* is decided purely by the crypto
 * in NfcManager, not by presence in this store.
 */
class NfcTagStore(context: Context) {

    private val prefs =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun getAll(): List<NfcTagRecord> {
        val raw = prefs.getString(KEY, null) ?: return emptyList()
        val arr = JSONArray(raw)
        return (0 until arr.length()).map { fromJson(arr.getJSONObject(it)) }
    }

    fun get(uuid: String): NfcTagRecord? = getAll().firstOrNull { it.uuid == uuid }

    fun put(record: NfcTagRecord) {
        val list = getAll().filter { it.uuid != record.uuid } + record
        persist(list)
    }

    fun rename(uuid: String, name: String?, locationType: String?) {
        val existing = get(uuid) ?: return
        put(existing.copy(name = name, locationType = locationType))
    }

    fun remove(uuid: String) = persist(getAll().filter { it.uuid != uuid })

    private fun persist(list: List<NfcTagRecord>) {
        val arr = JSONArray()
        list.forEach { r ->
            arr.put(JSONObject().apply {
                put("uuid", r.uuid)
                put("name", r.name ?: JSONObject.NULL)
                put("locationType", r.locationType ?: JSONObject.NULL)
                put("registeredAt", r.registeredAt)
            })
        }
        prefs.edit().putString(KEY, arr.toString()).apply()
    }

    private fun fromJson(o: JSONObject) = NfcTagRecord(
        uuid = o.getString("uuid"),
        name = if (o.isNull("name")) null else o.getString("name"),
        locationType = if (o.isNull("locationType")) null else o.getString("locationType"),
        registeredAt = o.optLong("registeredAt", 0L)
    )

    private companion object {
        const val PREFS = "near_field_tag_store"
        const val KEY = "tags_json"
    }
}
