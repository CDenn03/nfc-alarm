package com.example.nfcalarm.core

import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.security.KeyStore
import java.security.MessageDigest
import javax.crypto.KeyGenerator
import javax.crypto.Mac
import javax.crypto.SecretKey

/**
 * Owns the device-local HMAC-SHA256 secret used to sign/verify NFC tag payloads.
 *
 * The key is generated once, lives in the AndroidKeyStore (StrongBox where the
 * secure element supports HMAC), never leaves the device, and is never synced.
 */
object SecurityManager {

    private const val KEYSTORE = "AndroidKeyStore"
    private const val ALIAS = "nfc_alarm_hmac_v1"

    fun hmac(data: ByteArray): ByteArray {
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(getOrCreateKey())
        return mac.doFinal(data)
    }

    /** Constant-time verify of [expected] against HMAC([data]). */
    fun verify(data: ByteArray, expected: ByteArray): Boolean =
        MessageDigest.isEqual(hmac(data), expected)

    /** Call once early (e.g. engine setup) so the key exists before any tap. */
    fun ensureKey() {
        getOrCreateKey()
    }

    private fun getOrCreateKey(): SecretKey {
        val ks = KeyStore.getInstance(KEYSTORE).apply { load(null) }
        (ks.getEntry(ALIAS, null) as? KeyStore.SecretKeyEntry)?.let { return it.secretKey }
        return generateKey()
    }

    private fun generateKey(): SecretKey {
        // Prefer StrongBox, but not all secure elements support HMAC — and the
        // failure isn't always StrongBoxUnavailableException (some devices throw
        // ProviderException/KeyStoreException). Catch broadly and fall back to a
        // fresh TEE-backed key so key generation can never hard-crash.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            try {
                return buildKey(strongBox = true)
            } catch (_: Exception) {
                // fall through
            }
        }
        return buildKey(strongBox = false)
    }

    private fun buildKey(strongBox: Boolean): SecretKey {
        val kg = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_HMAC_SHA256, KEYSTORE)
        val spec = KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_SIGN)
            .setKeySize(256)
            .setDigests(KeyProperties.DIGEST_SHA256)
            .apply {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) setIsStrongBoxBacked(strongBox)
            }
            .build()
        kg.init(spec)
        return kg.generateKey()
    }
}
