package dev.cdenn.nearfield.core

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log

/**
 * Vibration testing for the alarm editor preview.
 * Supports different patterns to match the alarm vibration options.
 */
class VibrationTester(context: Context) {

    private val vibrator: Vibrator =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            manager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }

    /**
     * Start a test vibration with the given pattern.
     * @param patternCode 0=standard, 1=gentle, 2=strong, 3=heartbeat
     */
    fun test(patternCode: Int) {
        if (!vibrator.hasVibrator()) {
            Log.w(TAG, "Device has no vibrator")
            return
        }
        
        stop() // Stop any existing vibration first
        
        val timings = when (patternCode) {
            1 -> longArrayOf(0, 200, 400) // Gentle: shorter pulses, longer gaps
            2 -> longArrayOf(0, 800, 200) // Strong: longer pulses, shorter gaps
            3 -> longArrayOf(0, 150, 150, 150, 600) // Heartbeat: double pulse
            else -> longArrayOf(0, 500, 500) // Standard
        }
        
        try {
            vibrator.vibrate(VibrationEffect.createWaveform(timings, /* repeat = */ 0))
            Log.d(TAG, "Started test vibration with pattern $patternCode")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start vibration", e)
        }
    }

    fun stop() {
        try {
            vibrator.cancel()
        } catch (e: Exception) {
            Log.w(TAG, "Error stopping vibration", e)
        }
    }

    private companion object {
        const val TAG = "VibrationTester"
    }
}
