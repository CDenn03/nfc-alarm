package dev.cdenn.nearfield.data

import android.content.Context
import android.media.AudioAttributes
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri

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
    private var preview: Ringtone? = null

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
            }
        }
        return items
    }

    /**
     * Plays a short preview using alarm attributes so it is audible at the same
     * volume the alarm will use. Any previous preview is stopped first.
     */
    fun preview(uri: String) {
        stopPreview()
        runCatching {
            val ringtone = RingtoneManager.getRingtone(appContext, Uri.parse(uri)) ?: return
            ringtone.audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            ringtone.play()
            preview = ringtone
        }
    }

    fun stopPreview() {
        runCatching { preview?.takeIf { it.isPlaying }?.stop() }
        preview = null
    }

    private companion object {
        val TYPES = listOf(
            RingtoneManager.TYPE_ALARM to 0,
            RingtoneManager.TYPE_NOTIFICATION to 1,
            RingtoneManager.TYPE_RINGTONE to 2
        )
    }
}
