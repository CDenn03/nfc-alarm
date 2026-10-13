package com.example.nfcalarm.core

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

/**
 * Repeating vibration for the active alarm.
 * minSdk 26 guarantees VibrationEffect; VibratorManager is used on API 31+.
 */
class AlarmVibrator(context: Context) {

    private val vibrator: Vibrator =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            manager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }

    fun start() {
        if (!vibrator.hasVibrator()) return
        // wait 0ms, buzz 500ms, pause 500ms, repeat from index 0
        val timings = longArrayOf(0, 500, 500)
        vibrator.vibrate(VibrationEffect.createWaveform(timings, /* repeat = */ 0))
    }

    fun stop() = vibrator.cancel()
}
