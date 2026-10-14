package dev.cdenn.nearfield.data

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.util.Log

/** A selectable device sound. [kind] is 0 alarm, 1 notification, 2 ringtone. */
data class SoundItem(val uri: String, val title: String, val kind: Int)

/**
 * Enumerates the system sound catalogue via [RingtoneManager].
 *
 * Only bundled/system sounds are listed, which deliberately avoids needing
 * READ_MEDIA_AUDIO. Arbitrary user files remain reachable through the existing
 * document picker.
 */
class SoundLibrary(context: Context) {

    private val appContext = context.applicationContext
    private var previewPlayer: MediaPlayer? = null

    fun list(): List<SoundItem> {
        val items = mutableListOf<SoundItem>()
        val seenUris = mutableSetOf<String>()

        TYPES.forEach { (ringtoneType, kind) ->
            runCatching {
                val manager = RingtoneManager(appContext).apply {
                    setType(ringtoneType)
                }
                manager.cursor?.use { cursor ->
                    for (position in 0 until cursor.count) {
                        if (!cursor.moveToPosition(position)) continue
                        // Read the title before getRingtoneUri, which repositions
                        // the cursor internally.
                        val title = cursor
                            .getString(RingtoneManager.TITLE_COLUMN_INDEX)
                            ?.takeIf { it.isNotBlank() }
                            ?: continue
                        val uri = manager.getRingtoneUri(position)?.toString() ?: continue
                        if (seenUris.add(uri)) items += SoundItem(uri, title, kind)
                    }
                }
            }.onFailure { e ->
                Log.w(TAG, "Failed to enumerate sounds for type $ringtoneType", e)
            }
        }
        return items
    }

    /**
     * Plays a preview using MediaPlayer with alarm stream for reliable playback.
     * Any previous preview is stopped first.
     */
    fun preview(uri: String) {
        stopPreview()
        try {
            val player = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                setDataSource(appContext, Uri.parse(uri))
                isLooping = true
                prepareAsync()
                setOnPreparedListener { mp ->
                    mp.start()
                    Log.d(TAG, "Preview started for: $uri")
                }
                setOnErrorListener { _, what, extra ->
                    Log.e(TAG, "MediaPlayer error: what=$what, extra=$extra")
                    true
                }
            }
            previewPlayer = player
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start preview for: $uri", e)
        }
    }

    fun stopPreview() {
        previewPlayer?.let { player ->
            try {
                if (player.isPlaying) {
                    player.stop()
                }
                player.release()
                Log.d(TAG, "Preview stopped")
            } catch (e: Exception) {
                Log.w(TAG, "Error stopping preview", e)
            }
        }
        previewPlayer = null
    }

    private companion object {
        const val TAG = "SoundLibrary"
        val TYPES = listOf(
            RingtoneManager.TYPE_ALARM to 0,
            RingtoneManager.TYPE_NOTIFICATION to 1,
            RingtoneManager.TYPE_RINGTONE to 2
        )
    }
}
