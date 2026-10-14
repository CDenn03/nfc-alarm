package dev.cdenn.nearfield.core

import java.util.Collections

/**
 * Process-wide state for the single currently-ringing alarm's tag progress.
 *
 * Lives outside the Activity so tapped-tag progress survives Activity recreation
 * (rotation, relaunch from the full-screen-intent notification). AlarmService
 * sets it up on fire and clears it on dismiss/snooze; AlarmActivity reads/updates
 * it as tags are tapped.
 */
object AlarmSession {

    @Volatile
    var alarmId: String? = null
        private set

    @Volatile
    var requiredTagIds: List<String> = emptyList()
        private set

    private val tapped: MutableSet<String> = Collections.synchronizedSet(mutableSetOf())

    fun begin(id: String?, required: List<String>) {
        alarmId = id
        requiredTagIds = required
        tapped.clear()
    }

    fun clear() {
        alarmId = null
        requiredTagIds = emptyList()
        tapped.clear()
    }

    /** Records a tap. Returns true if this tag was newly added (progress changed). */
    fun tap(uuid: String): Boolean {
        if (uuid !in requiredTagIds) return false
        return tapped.add(uuid)
    }

    fun tappedCount(): Int = tapped.size

    fun remaining(): List<String> {
        val snapshot = synchronized(tapped) { tapped.toSet() }
        return requiredTagIds.filter { it !in snapshot }
    }

    fun isComplete(): Boolean {
        if (requiredTagIds.isEmpty()) return false
        return synchronized(tapped) { tapped.containsAll(requiredTagIds) }
    }
}
