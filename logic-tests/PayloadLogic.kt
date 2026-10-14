package dev.cdenn.nearfield.core
import java.security.SecureRandom

object PayloadLogic {
    val MAGIC = "ALM1".toByteArray(Charsets.US_ASCII)
    const val START_PAGE = 4; const val PAGE_SIZE = 4; const val READ_BLOCK = 16
    const val MAGIC_OFFSET = 0; const val UUID_OFFSET = 4; const val UUID_LEN = 16
    const val HMAC_OFFSET = 20; const val HMAC_LEN = 32; const val TOTAL_LEN = 64

    fun ByteArray.toHex(): String = joinToString("") { "%02x".format(it) }
    fun String.hexToBytes(): ByteArray = ByteArray(length / 2) { substring(it*2, it*2+2).toInt(16).toByte() }

    // mirrors writeNewTag payload assembly
    fun buildPayload(appUuid: ByteArray, hmac: ByteArray): ByteArray {
        val p = ByteArray(TOTAL_LEN)
        System.arraycopy(MAGIC, 0, p, MAGIC_OFFSET, MAGIC.size)
        System.arraycopy(appUuid, 0, p, UUID_OFFSET, UUID_LEN)
        System.arraycopy(hmac, 0, p, HMAC_OFFSET, HMAC_LEN)
        return p
    }
    // mirrors the page-write loop's page/offset math
    fun writePages(payload: ByteArray): List<Pair<Int, Int>> {
        val pages = mutableListOf<Pair<Int,Int>>()
        var offset = 0; var page = START_PAGE
        while (offset < TOTAL_LEN) { pages.add(page to offset); offset += PAGE_SIZE; page++ }
        return pages
    }
    // mirrors the read loop reassembly
    fun readReassemble(pageData: Map<Int, ByteArray>): ByteArray {
        val bytes = ByteArray(TOTAL_LEN)
        var read = 0; var page = START_PAGE
        while (read < TOTAL_LEN) {
            val block = pageData[page]!!
            val n = minOf(READ_BLOCK, TOTAL_LEN - read)
            System.arraycopy(block, 0, bytes, read, n)
            read += READ_BLOCK; page += 4
        }
        return bytes
    }
}
