package com.example.nfcalarm.core

import android.app.Activity
import android.content.Intent
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.EditText
import android.widget.TextView
import android.widget.Toast
import com.example.nfcalarm.R
import com.example.nfcalarm.data.AlarmStore
import com.example.nfcalarm.data.NfcTagStore
import com.example.nfcalarm.model.Alarm
import java.util.Locale

/**
 * Fully native ringing UI.
 *
 * Primary dismiss: tap all required NFC tags (AND logic, reader mode owned here
 * because enableReaderMode needs the foreground Activity). Fallback: a math
 * puzzle. Progress lives in [AlarmSession] so it survives Activity recreation.
 */
class AlarmActivity : Activity() {

    private var alarmId: String? = null
    private var alarm: Alarm? = null
    private val nfcAdapter: NfcAdapter? by lazy { NfcAdapter.getDefaultAdapter(this) }
    private val nfcManager = NfcManager()
    private lateinit var tagStore: NfcTagStore

    private var puzzle: MathPuzzle.Puzzle? = null
    private var wrongAttempts = 0

    private lateinit var progressText: TextView
    private lateinit var remainingText: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        showWhenLockedAndTurnScreenOn()
        setContentView(R.layout.activity_alarm)

        alarmId = intent.getStringExtra(AlarmConstants.EXTRA_ALARM_ID)
        alarm = alarmId?.let { AlarmStore(this).get(it) }
        tagStore = NfcTagStore(this)

        findViewById<TextView>(R.id.alarmTime).text = alarm?.let {
            String.format(Locale.getDefault(), "%02d:%02d", it.hour, it.minute)
        } ?: ""
        findViewById<TextView>(R.id.alarmLabel).text = alarm?.label ?: "Alarm"
        progressText = findViewById(R.id.progressText)
        remainingText = findViewById(R.id.remainingText)

        val requiresTags = AlarmSession.requiredTagIds.isNotEmpty()
        findViewById<View>(R.id.tagGroup).visibility = if (requiresTags) View.VISIBLE else View.GONE
        findViewById<Button>(R.id.dismissButton).apply {
            visibility = if (requiresTags) View.GONE else View.VISIBLE
            setOnClickListener { sendDismiss() }
        }
        findViewById<Button>(R.id.puzzleButton).apply {
            visibility = if (requiresTags) View.VISIBLE else View.GONE
            setOnClickListener { showPuzzle() }
        }
        findViewById<Button>(R.id.snoozeButton).apply {
            visibility = if (alarm?.allowSnooze != false) View.VISIBLE else View.GONE
            setOnClickListener { sendSnooze() }
        }

        setupPuzzleControls()
        if (requiresTags) updateProgress()
    }

    // ---- NFC ----

    override fun onResume() {
        super.onResume()
        if (AlarmSession.requiredTagIds.isNotEmpty()) enableReader()
    }

    override fun onPause() {
        runCatching { nfcAdapter?.disableReaderMode(this) }
        super.onPause()
    }

    private fun enableReader() {
        val adapter = nfcAdapter ?: return
        val flags = NfcAdapter.FLAG_READER_NFC_A or
            NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK or
            NfcAdapter.FLAG_READER_NO_PLATFORM_SOUNDS
        adapter.enableReaderMode(this, ::onTag, flags, null)
    }

    /** Binder thread — read + verify off the main thread, then marshal back. */
    private fun onTag(tag: Tag) {
        val valid: Boolean
        val uuid: String?
        try {
            val decoded = nfcManager.readTag(tag)
            valid = nfcManager.isValid(decoded)
            uuid = decoded.appUuidHex
        } catch (e: Exception) {
            runOnUiThread { toast("Couldn't read that tag — try again") }
            return
        }
        runOnUiThread { handleTap(uuid, valid) }
    }

    private fun handleTap(uuid: String?, valid: Boolean) {
        if (valid && uuid != null && AlarmSession.tap(uuid)) {
            updateProgress()
        } else if (valid && uuid != null && uuid in AlarmSession.requiredTagIds) {
            toast("Already tapped that one")
        } else {
            toast("Not one of this alarm's tags")
        }
    }

    private fun updateProgress() {
        val required = AlarmSession.requiredTagIds
        if (AlarmSession.isComplete()) {
            sendDismiss()
            return
        }
        progressText.text = "${AlarmSession.tappedCount()} of ${required.size} tags"
        val remainingNames = AlarmSession.remaining().map { uuid ->
            tagStore.get(uuid)?.name?.takeIf { it.isNotBlank() } ?: "Unnamed tag"
        }
        remainingText.text = "Tap: ${remainingNames.joinToString(", ")}"
    }

    // ---- Puzzle ----

    private fun setupPuzzleControls() {
        findViewById<Button>(R.id.puzzleSubmit).setOnClickListener { checkPuzzle() }
        findViewById<Button>(R.id.skipButton).setOnClickListener { skipPuzzle() }
    }

    private fun showPuzzle() {
        puzzle = MathPuzzle.generate()
        wrongAttempts = 0
        findViewById<TextView>(R.id.puzzleExpression).text = puzzle!!.expression
        findViewById<EditText>(R.id.puzzleAnswer).text?.clear()
        findViewById<TextView>(R.id.puzzleFeedback).text = ""
        findViewById<View>(R.id.skipButton).visibility = View.GONE
        findViewById<View>(R.id.puzzleGroup).visibility = View.VISIBLE
        findViewById<View>(R.id.puzzleButton).visibility = View.GONE
    }

    private fun checkPuzzle() {
        val p = puzzle ?: return
        val entered = findViewById<EditText>(R.id.puzzleAnswer).text.toString().trim().toIntOrNull()
        val feedback = findViewById<TextView>(R.id.puzzleFeedback)
        if (entered == p.answer) {
            sendDismiss() // solving is a valid dismiss path
            return
        }
        wrongAttempts++
        feedback.text = "Not quite — try again"
        findViewById<EditText>(R.id.puzzleAnswer).text?.clear()
        if (wrongAttempts >= MAX_WRONG) {
            findViewById<View>(R.id.skipButton).visibility = View.VISIBLE
        }
    }

    /** Skip only acknowledges — the alarm keeps ringing. */
    private fun skipPuzzle() {
        // Phase 5 records this to alarm history; for now just return to tags.
        findViewById<View>(R.id.puzzleGroup).visibility = View.GONE
        findViewById<View>(R.id.puzzleButton).visibility = View.VISIBLE
        toast("Alarm still ringing — tap your tags")
    }

    // ---- actions ----

    private fun sendDismiss() {
        startService(Intent(this, AlarmService::class.java).apply {
            action = AlarmConstants.ACTION_DISMISS
        })
        finish()
    }

    private fun sendSnooze() {
        startService(Intent(this, AlarmService::class.java).apply {
            action = AlarmConstants.ACTION_SNOOZE
            putExtra(AlarmConstants.EXTRA_ALARM_ID, alarmId)
        })
        finish()
    }

    private fun toast(msg: String) = Toast.makeText(this, msg, Toast.LENGTH_SHORT).show()

    private fun showWhenLockedAndTurnScreenOn() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    @Suppress("DEPRECATION", "MissingSuperCall")
    override fun onBackPressed() {
        // no-op: dismissal must go through tags/puzzle
    }

    private companion object {
        const val MAX_WRONG = 3
    }
}
