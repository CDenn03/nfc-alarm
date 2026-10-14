package dev.cdenn.nearfield.core

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log

/**
 * Plays the alarm sound on the ALARM stream and ramps player volume 0 -> 1 over
 * [AlarmConstants.CRESCENDO_SECONDS]. Never touches the system alarm-stream
 * volume.
 *
 * FIX #5: if the chosen sound fails to prepare/play (e.g. a persisted content://
 * URI that's since become unreadable), it retries ONCE with the device default
 * alarm ringtone. A silent alarm is the worst possible failure, so it must
 * always fall back to making noise.
 */
class AlarmAudioPlayer(private val context: Context) {

    private var player: MediaPlayer? = null
    private val handler = Handler(Looper.getMainLooper())
    private var step = 0
    private var crescendoSeconds = AlarmConstants.CRESCENDO_SECONDS
    private var usedFallback = false

    fun start(soundUri: String?, crescendoSeconds: Int = AlarmConstants.CRESCENDO_SECONDS) {
        this.crescendoSeconds = crescendoSeconds.coerceAtLeast(1)
        val uri = soundUri?.let(Uri::parse) ?: defaultAlarmUri()
        prepareAndPlay(uri)
    }

    private fun prepareAndPlay(uri: Uri) {
        releasePlayer()
        player = MediaPlayer().apply {
            setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
            isLooping = true
            setVolume(0f, 0f)
            setOnPreparedListener { mp ->
                mp.start()
                startRamp()
            }
            setOnErrorListener { _, what, extra ->
                Log.e(TAG, "MediaPlayer error what=$what extra=$extra (uri=$uri)")
                fallbackToDefault()
                true
            }
            try {
                setDataSource(context, uri)
                prepareAsync()
            } catch (t: Throwable) {
                Log.e(TAG, "setDataSource failed for $uri", t)
                fallbackToDefault()
            }
        }
    }

    private fun fallbackToDefault() {
        if (usedFallback) return
        usedFallback = true
        Log.w(TAG, "Falling back to default alarm ringtone")
        // Post so we don't rebuild the player from inside its own error callback.
        handler.post { runCatching { prepareAndPlay(defaultAlarmUri()) } }
    }

    private fun startRamp() {
        step = 0
        val ramp = object : Runnable {
            override fun run() {
                val v = (step.toFloat() / crescendoSeconds).coerceIn(0f, 1f)
                player?.setVolume(v, v)
                if (step < crescendoSeconds) {
                    step++
                    handler.postDelayed(this, 1000L)
                }
            }
        }
        handler.post(ramp)
    }

    fun stop() {
        handler.removeCallbacksAndMessages(null)
        releasePlayer()
    }

    private fun releasePlayer() {
        player?.let {
            runCatching { if (it.isPlaying) it.stop() }
            runCatching { it.reset() }
            runCatching { it.release() }
        }
        player = null
    }

    private fun defaultAlarmUri(): Uri =
        RingtoneManager.getActualDefaultRingtoneUri(context, RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)

    private companion object {
        const val TAG = "AlarmAudioPlayer"
    }
}
