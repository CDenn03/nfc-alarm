package dev.cdenn.nearfield.core

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import dev.cdenn.nearfield.data.AlarmStore
import dev.cdenn.nearfield.pigeon.AlarmBridge

class AlarmService : Service() {

    private lateinit var wakeLock: PowerManager.WakeLock
    private var audio: AlarmAudioPlayer? = null
    private var vibrator: AlarmVibrator? = null
    private var currentAlarmId: String? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, WAKELOCK_TAG)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            AlarmConstants.ACTION_ALARM_FIRE ->
                startAlarm(intent.getStringExtra(AlarmConstants.EXTRA_ALARM_ID))
            AlarmConstants.ACTION_DISMISS -> dismiss()
            AlarmConstants.ACTION_SNOOZE -> snooze()
            else -> if (currentAlarmId == null) stopSelf()
        }
        return START_REDELIVER_INTENT
    }

    private fun startAlarm(alarmId: String?) {
        if (alarmId == null) {
            stopSelf(); return
        }
        currentAlarmId = alarmId
        val alarm = AlarmStore(this).get(alarmId)

        AlarmSession.begin(alarmId, alarm?.requiredTagIds ?: emptyList())

        if (!wakeLock.isHeld) wakeLock.acquire(AlarmConstants.WAKELOCK_TIMEOUT_MS)
        startInForeground(alarm?.label ?: "Alarm", alarmId)

        audio = AlarmAudioPlayer(this).also { it.start(alarm?.soundUri, AlarmConstants.CRESCENDO_SECONDS) }
        if (alarm?.vibrate != false) vibrator = AlarmVibrator(this).also { it.start() }

        startActivity(
            Intent(this, AlarmActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                .putExtra(AlarmConstants.EXTRA_ALARM_ID, alarmId)
        )
    }

    private fun dismiss() {
        val id = currentAlarmId
        teardown()
        AlarmBridge.flutterApi?.onAlarmStateChanged(id ?: return, "dismissed") { }
    }

    private fun snooze() {
        val id = currentAlarmId
        if (id != null) {
            val minutes = AlarmStore(this).get(id)?.snoozeMinutes ?: 5
            AlarmScheduler(this).scheduleSnooze(id, minutes)
        }
        teardown()
        AlarmBridge.flutterApi?.onAlarmStateChanged(id ?: return, "snoozed") { }
    }

    private fun teardown() {
        audio?.stop(); audio = null
        vibrator?.stop(); vibrator = null
        if (wakeLock.isHeld) wakeLock.release()
        AlarmSession.clear()
        currentAlarmId = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun startInForeground(label: String, alarmId: String) {
        val notification = buildNotification(label, alarmId)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                AlarmConstants.FOREGROUND_NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            )
        } else {
            startForeground(AlarmConstants.FOREGROUND_NOTIFICATION_ID, notification)
        }
    }

    private fun buildNotification(label: String, alarmId: String): Notification {
        val fullScreenPending = PendingIntent.getActivity(
            this,
            alarmId.hashCode(),
            Intent(this, AlarmActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                .putExtra(AlarmConstants.EXTRA_ALARM_ID, alarmId),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, AlarmConstants.CHANNEL_ID)
            .setContentTitle(label)
            .setContentText("Tap to open alarm")
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setOngoing(true)
            .setAutoCancel(false)
            .setFullScreenIntent(fullScreenPending, true)
            .setContentIntent(fullScreenPending)
            .build()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(AlarmConstants.CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            AlarmConstants.CHANNEL_ID, AlarmConstants.CHANNEL_NAME, NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Shows the active alarm over the lock screen"
            setBypassDnd(true)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            setSound(null, null)
            enableVibration(false)
        }
        manager.createNotificationChannel(channel)
    }

    override fun onDestroy() {
        audio?.stop()
        vibrator?.stop()
        if (::wakeLock.isInitialized && wakeLock.isHeld) wakeLock.release()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private companion object {
        const val WAKELOCK_TAG = "nfcalarm:AlarmService"
    }
}
