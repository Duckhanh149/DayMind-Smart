package dev.daymind.daymind_smart

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** No passwords; tokens are encrypted with an OS-owned, non-exportable key. */
internal class SecureStore(private val context: Context) {
    private val alias = "dev.daymind.session.v1"
    private fun key(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey(alias, null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setRandomizedEncryptionRequired(true).build())
        }.generateKey()
    }
    fun handle(call: MethodCall, result: MethodChannel.Result) {
        try {
            val name = call.argument<String>("key")
            require(name in setOf("session", "installation", "test_probe"))
            val prefs = context.getSharedPreferences("daymind_secure_v1", Context.MODE_PRIVATE)
            when (call.method) {
                "read" -> {
                    val encoded = prefs.getString(name, null)
                    if (encoded == null) { result.success(null); return }
                    require(encoded.length <= 90000)
                    val bytes = Base64.decode(encoded, Base64.NO_WRAP)
                    require(bytes.size in 29..65536)
                    val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                    cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, bytes.copyOfRange(0, 12)))
                    cipher.updateAAD(name!!.toByteArray(Charsets.UTF_8))
                    val plain = cipher.doFinal(bytes.copyOfRange(12, bytes.size))
                    require(plain.size <= 49152)
                    result.success(plain.toString(Charsets.UTF_8))
                }
                "write" -> {
                    val value = call.argument<String>("value")!!.toByteArray(Charsets.UTF_8)
                    require(value.size in 1..49152)
                    val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                    cipher.init(Cipher.ENCRYPT_MODE, key())
                    require(cipher.iv.size == 12)
                    cipher.updateAAD(name!!.toByteArray(Charsets.UTF_8))
                    val blob = cipher.iv + cipher.doFinal(value)
                    check(prefs.edit().putString(name, Base64.encodeToString(blob, Base64.NO_WRAP)).commit())
                    result.success(null)
                }
                "delete" -> { check(prefs.edit().remove(name).commit()); result.success(null) }
                else -> result.notImplemented()
            }
        } catch (_: Exception) {
            result.error("SECURE_STORAGE", "Không truy cập được kho phiên đăng nhập của hệ điều hành.", null)
        }
    }
}
