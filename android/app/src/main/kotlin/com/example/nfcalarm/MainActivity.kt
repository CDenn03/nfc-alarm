package com.example.nfcalarm

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.example.nfcalarm.core.NfcManager
import com.example.nfcalarm.core.SecurityManager
import com.example.nfcalarm.data.NfcTagRecord
import com.example.nfcalarm.data.NfcTagStore
import com.example.nfcalarm.pigeon.AlarmBridge
import com.example.nfcalarm.pigeon.AlarmFlutterApi
import com.example.nfcalarm.pigeon.AlarmHostApi
import com.example.nfcalarm.pigeon.AlarmHostApiImpl
import com.example.nfcalarm.pigeon.NfcHostApi
import com.example.nfcalarm.pigeon.NfcScanResult
import com.example.nfcalarm.pigeon.NfcTagDto
import com.example.nfcalarm.pigeon.SoundSelection
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * Registers both Pigeon host APIs and owns the Activity-scoped operations:
 * sound picking, notification-permission requests, and the NFC reader-mode
 * session for tag registration and diagnostic scans.
 *
 * FIX: the NFC op is claimed atomically ([consumeOp]) so exactly one of
 * {tag discovered, timeout, cancel, pause} resolves the Dart callback — no more
 * double-resolution race between the binder thread and the main thread.
 */
class MainActivity : FlutterActivity(), NfcHostApi {

    private var pendingSoundCallback: ((Result<SoundSelection?>) -> Unit)? = null
    private var pendingNotifCallback: ((Result<Boolean>) -> Unit)? = null

    private val nfcAdapter: NfcAdapter? by lazy { NfcAdapter.getDefaultAdapter(this) }
    private val nfcManager = NfcManager()
    private val nfcTimeout = Handler(Looper.getMainLooper())

    private val nfcLock = Any()
    private var nfcOp: NfcOp? = null

    private sealed class NfcOp {
        class Register(
            val name: String?,
            val location: String?,
            val cb: (Result<NfcTagDto>) -> Unit
        ) : NfcOp()

        class Scan(val cb: (Result<NfcScanResult>) -> Unit) : NfcOp()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        SecurityManager.ensureKey()

        AlarmHostApi.setUp(
            messenger,
            AlarmHostApiImpl(
                context = applicationContext,
                launchSoundPicker = { cb -> launchSoundPicker(cb) },
                requestNotificationPermission = { cb -> requestNotificationPermission(cb) }
            )
        )
        NfcHostApi.setUp(messenger, this)
        AlarmBridge.flutterApi = AlarmFlutterApi(messenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        AlarmBridge.flutterApi = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    // ============ NfcHostApi ============

    override fun nfcAvailability(): Long {
        val adapter = nfcAdapter ?: return 0L // unsupported
        return if (adapter.isEnabled) 2L else 1L // ready : disabled
    }

    override fun openNfcSettings() {
        runCatching { startActivity(Intent(Settings.ACTION_NFC_SETTINGS)) }
    }

    override fun beginTagRegistration(
        name: String?,
        locationType: String?,
        callback: (Result<NfcTagDto>) -> Unit
    ) {
        startNfc(NfcOp.Register(name, locationType, callback)) {
            callback(Result.failure(NfcManager.NfcException(it)))
        }
    }

    override fun beginTagScan(callback: (Result<NfcScanResult>) -> Unit) {
        startNfc(NfcOp.Scan(callback)) {
            callback(Result.success(NfcScanResult(false, false, null, it)))
        }
    }

    override fun cancelNfc() {
        val op = consumeOp() ?: return
        resolveOnMain { resolveCancelled(op) }
    }

    override fun getTags(): List<NfcTagDto> =
        NfcTagStore(applicationContext).getAll().map { it.toDto() }

    override fun deleteTag(uuid: String) = NfcTagStore(applicationContext).remove(uuid)

    override fun renameTag(uuid: String, name: String, locationType: String?) =
        NfcTagStore(applicationContext).rename(uuid, name, locationType)

    // ---- NFC session plumbing (atomic single-resolution) ----

    private fun consumeOp(): NfcOp? = synchronized(nfcLock) {
        val op = nfcOp
        nfcOp = null
        op
    }

    private fun setOp(op: NfcOp) = synchronized(nfcLock) { nfcOp = op }

    private fun hasOp(): Boolean = synchronized(nfcLock) { nfcOp != null }

    private fun startNfc(op: NfcOp, onUnavailable: (String) -> Unit) {
        val adapter = nfcAdapter
        if (adapter == null) {
            onUnavailable("This device has no NFC."); return
        }
        if (!adapter.isEnabled) {
            onUnavailable("NFC is turned off. Enable it in Settings."); return
        }
        cancelNfc() // resolve any prior op as cancelled
        setOp(op)

        val flags = NfcAdapter.FLAG_READER_NFC_A or
            NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK or
            NfcAdapter.FLAG_READER_NO_PLATFORM_SOUNDS
        adapter.enableReaderMode(this, ::onTagDiscovered, flags, null)
        nfcTimeout.postDelayed(::onNfcTimeout, TAG_TIMEOUT_MS)
    }

    /** Binder thread. Claims the op atomically, then does blocking tag IO. */
    private fun onTagDiscovered(tag: Tag) {
        val op = consumeOp() ?: return
        try {
            when (op) {
                is NfcOp.Register -> {
                    val uuidHex = nfcManager.writeNewTag(tag)
                    val record = NfcTagRecord(
                        uuid = uuidHex,
                        name = op.name,
                        locationType = op.location,
                        registeredAt = System.currentTimeMillis()
                    )
                    NfcTagStore(applicationContext).put(record)
                    resolveOnMain { op.cb(Result.success(record.toDto())) }
                }

                is NfcOp.Scan -> {
                    val decoded = nfcManager.readTag(tag)
                    val valid = nfcManager.isValid(decoded)
                    val known = NfcTagStore(applicationContext).get(decoded.appUuidHex) != null
                    resolveOnMain {
                        op.cb(
                            Result.success(
                                NfcScanResult(
                                    valid = valid,
                                    alreadyRegistered = known,
                                    uuid = if (decoded.magicOk) decoded.appUuidHex else null,
                                    errorMessage = null
                                )
                            )
                        )
                    }
                }
            }
        } catch (e: Exception) {
            resolveOnMain {
                when (op) {
                    is NfcOp.Register -> op.cb(Result.failure(e))
                    is NfcOp.Scan -> op.cb(
                        Result.success(NfcScanResult(false, false, null, e.message ?: "Tag error."))
                    )
                }
            }
        }
    }

    private fun onNfcTimeout() {
        val op = consumeOp() ?: return
        resolveOnMain {
            when (op) {
                is NfcOp.Register -> op.cb(Result.failure(NfcManager.NfcException("No tag detected. Try again.")))
                is NfcOp.Scan -> op.cb(Result.success(NfcScanResult(false, false, null, "No tag detected.")))
            }
        }
    }

    private fun resolveCancelled(op: NfcOp) = when (op) {
        is NfcOp.Register -> op.cb(Result.failure(NfcManager.NfcException("Cancelled.")))
        is NfcOp.Scan -> op.cb(Result.success(NfcScanResult(false, false, null, "Cancelled.")))
    }

    /** Always tears down reader mode and resolves on the main thread. */
    private fun resolveOnMain(block: () -> Unit) {
        runOnUiThread {
            nfcTimeout.removeCallbacks(::onNfcTimeout)
            runCatching { nfcAdapter?.disableReaderMode(this) }
            block()
        }
    }

    override fun onPause() {
        if (hasOp()) cancelNfc()
        super.onPause()
    }

    private fun NfcTagRecord.toDto() =
        NfcTagDto(uuid = uuid, registeredAt = registeredAt, name = name, locationType = locationType)

    // ============ POST_NOTIFICATIONS ============

    private fun requestNotificationPermission(callback: (Result<Boolean>) -> Unit) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            callback(Result.success(true)); return
        }
        val granted = ContextCompat.checkSelfPermission(
            this, Manifest.permission.POST_NOTIFICATIONS
        ) == PackageManager.PERMISSION_GRANTED
        if (granted) {
            callback(Result.success(true)); return
        }
        pendingNotifCallback?.invoke(Result.success(false))
        pendingNotifCallback = callback
        ActivityCompat.requestPermissions(
            this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQ_NOTIF
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQ_NOTIF) return
        val callback = pendingNotifCallback
        pendingNotifCallback = null
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        callback?.invoke(Result.success(granted))
    }

    // ============ Sound picker ============

    private fun launchSoundPicker(callback: (Result<SoundSelection?>) -> Unit) {
        pendingSoundCallback?.invoke(Result.success(null))
        pendingSoundCallback = callback

        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "audio/*"
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
            )
        }
        runCatching { startActivityForResult(intent, REQ_PICK_SOUND) }
            .onFailure {
                pendingSoundCallback?.invoke(Result.success(null))
                pendingSoundCallback = null
            }
    }

    @Deprecated("Classic result API; FlutterActivity isn't a ComponentActivity")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQ_PICK_SOUND) return

        val callback = pendingSoundCallback
        pendingSoundCallback = null

        val uri = data?.data
        if (resultCode == RESULT_OK && uri != null) {
            runCatching {
                contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            val name = queryDisplayName(uri) ?: "Custom sound"
            callback?.invoke(Result.success(SoundSelection(uri.toString(), name)))
        } else {
            callback?.invoke(Result.success(null))
        }
    }

    private fun queryDisplayName(uri: Uri): String? =
        runCatching {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                ?.use { c -> if (c.moveToFirst()) c.getString(0) else null }
        }.getOrNull()

    private companion object {
        const val REQ_PICK_SOUND = 7001
        const val REQ_NOTIF = 7002
        const val TAG_TIMEOUT_MS = 25_000L
    }
}
