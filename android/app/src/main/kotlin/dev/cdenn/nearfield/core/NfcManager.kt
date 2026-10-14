package dev.cdenn.nearfield.core

import android.nfc.Tag
import android.nfc.tech.MifareUltralight
import java.io.IOException
import java.security.SecureRandom

/**
 * Reads/writes the encrypted alarm payload on NTAG215 (MIFARE Ultralight) tags.
 *
 * Payload layout (64 bytes, on user-memory pages 4..19; each page = 4 bytes):
 *   page 4        magic  "ALM1"              (4 bytes)
 *   pages 5..8    app UUID                    (16 bytes, random per tag)
 *   pages 9..16   HMAC-SHA256(hwUID ‖ UUID)   (32 bytes)
 *   pages 17..19  reserved (zero)             (12 bytes)  — future alarm-id binding
 *
 * The HMAC covers the tag's factory hardware UID, so copying the payload to a
 * different physical tag fails verification.
 */
class NfcManager {

    class NfcException(message: String) : Exception(message)

    data class Decoded(
        val appUuidHex: String,
        val hmac: ByteArray,
        val hardwareUid: ByteArray,
        val magicOk: Boolean
    )

    /** Writes a fresh payload to [tag]; returns the generated app-UUID (hex). */
    fun writeNewTag(tag: Tag): String {
        val mul = MifareUltralight.get(tag)
            ?: throw NfcException("This isn't an NTAG/MIFARE Ultralight tag.")

        val hwUid = tag.id
        val appUuid = ByteArray(UUID_LEN).also { SecureRandom().nextBytes(it) }
        val hmac = SecurityManager.hmac(hwUid + appUuid)

        val payload = ByteArray(TOTAL_LEN)
        System.arraycopy(MAGIC, 0, payload, MAGIC_OFFSET, MAGIC.size)
        System.arraycopy(appUuid, 0, payload, UUID_OFFSET, UUID_LEN)
        System.arraycopy(hmac, 0, payload, HMAC_OFFSET, HMAC_LEN)
        // reserved region stays zero

        mul.use { ul ->
            ul.connect()
            var offset = 0
            var page = START_PAGE
            while (offset < TOTAL_LEN) {
                writePageWithRetry(ul, page, payload.copyOfRange(offset, offset + PAGE_SIZE))
                offset += PAGE_SIZE
                page++
            }
        }
        return appUuid.toHex()
    }

    /** Reads and decodes [tag]. Does not verify — call [isValid] on the result. */
    fun readTag(tag: Tag): Decoded {
        val mul = MifareUltralight.get(tag)
            ?: throw NfcException("This isn't an NTAG/MIFARE Ultralight tag.")

        val bytes = ByteArray(TOTAL_LEN)
        mul.use { ul ->
            ul.connect()
            var read = 0
            var page = START_PAGE
            while (read < TOTAL_LEN) {
                val block = readPagesWithRetry(ul, page) // 16 bytes (4 pages)
                val n = minOf(READ_BLOCK, TOTAL_LEN - read)
                System.arraycopy(block, 0, bytes, read, n)
                read += READ_BLOCK
                page += 4
            }
        }

        val magicOk = bytes.copyOfRange(MAGIC_OFFSET, MAGIC_OFFSET + MAGIC.size).contentEquals(MAGIC)
        val appUuid = bytes.copyOfRange(UUID_OFFSET, UUID_OFFSET + UUID_LEN)
        val hmac = bytes.copyOfRange(HMAC_OFFSET, HMAC_OFFSET + HMAC_LEN)
        return Decoded(appUuid.toHex(), hmac, tag.id, magicOk)
    }

    /** True only if the magic matches AND the UID-bound HMAC verifies. */
    fun isValid(decoded: Decoded): Boolean =
        decoded.magicOk &&
            SecurityManager.verify(decoded.hardwareUid + decoded.appUuidHex.hexToBytes(), decoded.hmac)

    private fun writePageWithRetry(mul: MifareUltralight, page: Int, data: ByteArray) {
        var attempts = 0
        while (true) {
            try {
                mul.writePage(page, data)
                return
            } catch (e: IOException) {
                if (++attempts >= MAX_RETRY) {
                    throw NfcException("Couldn't write the tag. Hold it flat against the phone and try again.")
                }
                sleep()
            }
        }
    }

    private fun readPagesWithRetry(mul: MifareUltralight, page: Int): ByteArray {
        var attempts = 0
        while (true) {
            try {
                return mul.readPages(page)
            } catch (e: IOException) {
                if (++attempts >= MAX_RETRY) {
                    throw NfcException("Couldn't read the tag. Hold it steady and try again.")
                }
                sleep()
            }
        }
    }

    private fun sleep() = try {
        Thread.sleep(RETRY_DELAY_MS)
    } catch (_: InterruptedException) {
        Thread.currentThread().interrupt()
    }

    private fun ByteArray.toHex(): String =
        joinToString("") { "%02x".format(it) }

    private fun String.hexToBytes(): ByteArray =
        ByteArray(length / 2) { substring(it * 2, it * 2 + 2).toInt(16).toByte() }

    private companion object {
        val MAGIC = "ALM1".toByteArray(Charsets.US_ASCII)

        const val START_PAGE = 4
        const val PAGE_SIZE = 4
        const val READ_BLOCK = 16 // MifareUltralight.readPages returns 4 pages

        const val MAGIC_OFFSET = 0
        const val UUID_OFFSET = 4
        const val UUID_LEN = 16
        const val HMAC_OFFSET = 20
        const val HMAC_LEN = 32
        const val TOTAL_LEN = 64

        const val MAX_RETRY = 4
        const val RETRY_DELAY_MS = 150L
    }
}
