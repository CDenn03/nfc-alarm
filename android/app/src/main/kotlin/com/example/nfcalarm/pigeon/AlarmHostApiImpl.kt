package com.example.nfcalarm.pigeon

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import android.provider.Settings
import com.example.nfcalarm.core.AlarmScheduler
import com.example.nfcalarm.data.AlarmStore
import com.example.nfcalarm.data.SoundLibrary
import com.example.nfcalarm.model.Alarm
import java.time.LocalDate
import java.util.Calendar

class AlarmHostApiImpl(
    private val context: Context,
    private val launchSoundPicker: (callback: (Result<SoundSelection?>) -> Unit) -> Unit,
    private val requestNotificationPermission: (callback: (Result<Boolean>) -> Unit) -> Unit
) : AlarmHostApi {

    private val store = AlarmStore(context)
    private val scheduler = AlarmScheduler(context)
    private val sounds = SoundLibrary(context)

    override fun getAlarms(): List<AlarmDto> = store.getAll().map { it.toDto() }

    override fun upsertAlarm(alarm: AlarmDto) {
        val model = alarm.toModel()
        store.put(model)
        scheduler.schedule(model)
    }

    override fun deleteAlarm(id: String) {
        scheduler.cancel(id)
        store.remove(id)
    }

    override fun setEnabled(id: String, enabled: Boolean) {
        val existing = store.get(id) ?: return
        // Re-enabling clears a stale "off for today" so the switch is predictable.
        val updated = existing.copy(
            enabled = enabled,
            skipDateEpochDay = if (enabled) 0L else existing.skipDateEpochDay
        )
        store.put(updated)
        scheduler.schedule(updated)
    }

    override fun skipNextOccurrence(id: String) {
        val alarm = store.get(id) ?: return
        // The scheduler owns the schedule math, so ask it which date to skip.
        val nextTrigger = scheduler.nextTriggerMillis(alarm) ?: return
        val date = Calendar.getInstance().apply { timeInMillis = nextTrigger }
        val epochDay = LocalDate.of(
            date.get(Calendar.YEAR),
            date.get(Calendar.MONTH) + 1,
            date.get(Calendar.DAY_OF_MONTH)
        ).toEpochDay()

        val updated = alarm.copy(skipDateEpochDay = epochDay)
        store.put(updated)
        scheduler.schedule(updated)
    }

    override fun clearSkipNext(id: String) {
        val updated = (store.get(id) ?: return).copy(skipDateEpochDay = 0L)
        store.put(updated)
        scheduler.schedule(updated)
    }

    override fun pickAlarmSound(callback: (Result<SoundSelection?>) -> Unit) = launchSoundPicker(callback)

    override fun displayNameForUri(uri: String): String? = queryDisplayName(Uri.parse(uri))

    override fun listSounds(): List<SoundItemDto> = sounds.list().map {
        SoundItemDto(uri = it.uri, title = it.title, kind = it.kind.toLong())
    }

    override fun previewSound(uri: String) = sounds.preview(uri)

    override fun stopSoundPreview() = sounds.stopPreview()

    override fun canScheduleExactAlarms(): Boolean = scheduler.canScheduleExact()

    override fun canUseFullScreenIntent(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return true
        return context.getSystemService(NotificationManager::class.java).canUseFullScreenIntent()
    }

    override fun openExactAlarmSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
        startSettings(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, withPackageUri = true)
    }

    override fun openFullScreenIntentSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return
        startSettings(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, withPackageUri = true)
    }

    override fun ensureNotificationPermission(callback: (Result<Boolean>) -> Unit) =
        requestNotificationPermission(callback)

    override fun openNotificationSettings() {
        val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
            putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        runCatching { context.startActivity(intent) }
    }

    override fun ping(message: String): String = "pong:$message"

    private fun startSettings(action: String, withPackageUri: Boolean) {
        val intent = Intent(action).apply {
            if (withPackageUri) data = Uri.parse("package:${context.packageName}")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        runCatching { context.startActivity(intent) }
    }

    private fun queryDisplayName(uri: Uri): String? =
        runCatching {
            context.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                ?.use { c -> if (c.moveToFirst()) c.getString(0) else null }
        }.getOrNull()

    private fun AlarmDto.toModel() = Alarm(
        id = id,
        hour = hour.toInt(),
        minute = minute.toInt(),
        repeatDays = repeatDays.filterNotNull(),
        enabled = enabled,
        soundUri = soundUri,
        vibrate = vibrate,
        label = label,
        requiredTagIds = requiredTagIds.filterNotNull(),
        allowSnooze = allowSnooze,
        snoozeMinutes = snoozeMinutes.toInt(),
        recurrenceKind = recurrenceKind.toInt(),
        intervalWeeks = intervalWeeks.toInt().coerceAtLeast(1),
        nthOfMonth = nthOfMonth.toInt(),
        weekdayOfMonth = weekdayOfMonth.toInt().coerceIn(0, 6),
        dayOfMonth = dayOfMonth.toInt().coerceIn(1, 31),
        anchorEpochDay = anchorEpochDay,
        skipDateEpochDay = skipDateEpochDay
    )

    private fun Alarm.toDto() = AlarmDto(
        id = id,
        hour = hour.toLong(),
        minute = minute.toLong(),
        repeatDays = repeatDays,
        enabled = enabled,
        vibrate = vibrate,
        label = label,
        requiredTagIds = requiredTagIds,
        allowSnooze = allowSnooze,
        snoozeMinutes = snoozeMinutes.toLong(),
        recurrenceKind = recurrenceKind.toLong(),
        intervalWeeks = intervalWeeks.toLong(),
        nthOfMonth = nthOfMonth.toLong(),
        weekdayOfMonth = weekdayOfMonth.toLong(),
        dayOfMonth = dayOfMonth.toLong(),
        anchorEpochDay = anchorEpochDay,
        skipDateEpochDay = skipDateEpochDay,
        soundUri = soundUri
    )
}
