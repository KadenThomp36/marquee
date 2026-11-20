package dev.kadenthompson.marquee.net

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.first
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

private val Context.vaultStore by preferencesDataStore(name = "vault")

/**
 * The paired server — address and token — encrypted with an AES-GCM key that lives in
 * the Android Keystore and never leaves it. The ciphertext sits in DataStore, which is
 * excluded from backups (see data_extraction_rules.xml). One item, replaced wholesale.
 */
class Vault(private val context: Context) {

    private val alias = "marquee.session.v1"
    private val key = stringPreferencesKey("paired_server")

    private fun secretKey(): SecretKey {
        val ks = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (ks.getEntry(alias, null) as? KeyStore.SecretKeyEntry)?.let { return it.secretKey }
        val gen = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        gen.init(
            KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build()
        )
        return gen.generateKey()
    }

    suspend fun load(): PairedServer? = runCatching {
        val blob = context.vaultStore.data.first()[key] ?: return null
        val raw = Base64.decode(blob, Base64.NO_WRAP)
        val iv = raw.copyOfRange(0, 12)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, secretKey(), GCMParameterSpec(128, iv))
        val json = String(cipher.doFinal(raw.copyOfRange(12, raw.size)), Charsets.UTF_8)
        MarqueeJson.decodeFromString<PairedServer>(json)
    }.getOrNull()

    suspend fun save(server: PairedServer) {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, secretKey())
        val sealed = cipher.iv + cipher.doFinal(MarqueeJson.encodeToString(PairedServer.serializer(), server).toByteArray())
        context.vaultStore.edit { it[key] = Base64.encodeToString(sealed, Base64.NO_WRAP) }
    }

    /** Unpair: forget the address and the token. Revoke server-side first. */
    suspend fun clear() {
        context.vaultStore.edit { it.remove(key) }
    }
}
