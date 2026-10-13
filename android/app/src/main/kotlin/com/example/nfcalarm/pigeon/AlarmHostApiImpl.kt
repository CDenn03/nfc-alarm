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
import com.example.nfcalarm.model.Alarm

class AlarmHostApiImpl(
    private val context: Context,
    private val launchSoundPicker: (callback: (Result<SoundSelection?>) -> Unit) -> Unit,
    private val requestNotificationPermission: (callback: (Result<Boolean>) -> Unit) -> Unit
) : AlarmHostApi {

    private val store = AlarmStore(context)
    private val scheduler = AlarmScheduler(context)

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
        val updated = (store.get(id) ?: return).copy(enabled = enabled)
        store.put(updated)
        scheduler.schedule(updated)
    }

    override fun pickAlarmSound(callback: (Result<SoundSelection?>) -> Unit) = launchSoundPicker(callback)

    override fun displayNameForUri(uri: String): String? = queryDisplayName(Uri.parse(uri))

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
        snoozeMinutes = snoozeMinutes.toInt()
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
        soundUri = soundUri
    )
}
