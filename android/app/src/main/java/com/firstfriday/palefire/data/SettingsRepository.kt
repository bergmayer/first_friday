package com.firstfriday.palefire.data

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import androidx.core.content.edit
import org.json.JSONArray
import org.json.JSONObject
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

class SettingsRepository(context: Context) {
    private val preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)

    fun loadSettings(): ServerSettings? {
        val serverUrl = preferences.getString(SERVER_URL, null)?.takeIf { it.isNotBlank() }
            ?: return null
        return ServerSettings(
            serverUrl = serverUrl,
            username = preferences.getString(USERNAME, "").orEmpty(),
            password = decrypt(preferences.getString(PASSWORD, null)).orEmpty(),
            imageDurationMillis = preferences
                .getLong(IMAGE_DURATION_MILLIS, GalleryDefaults.IMAGE_DURATION_MILLIS)
                .takeIf { it > 0 }
                ?: GalleryDefaults.IMAGE_DURATION_MILLIS,
            audioMode = preferences.getString(AUDIO_MODE, null)
                ?.let { runCatching { AudioMode.valueOf(it) }.getOrNull() }
                ?: AudioMode.STATIONS,
            stationId = preferences.getString(STATION_ID, GalleryDefaults.STATION_ID)
                .orEmpty()
                .ifBlank { GalleryDefaults.STATION_ID },
            radioUrl = preferences.getString(RADIO_URL, "").orEmpty(),
        )
    }

    fun saveSettings(settings: ServerSettings) {
        preferences.edit {
            putString(SERVER_URL, settings.serverUrl)
            putString(USERNAME, settings.username)
            putString(PASSWORD, encrypt(settings.password))
            putLong(IMAGE_DURATION_MILLIS, settings.imageDurationMillis)
            putString(AUDIO_MODE, settings.audioMode.name)
            putString(STATION_ID, settings.stationId)
            putString(RADIO_URL, settings.radioUrl)
        }
    }

    fun loadIndex(forServerUrl: String): List<Artwork> {
        if (preferences.getString(INDEX_SERVER_URL, null) != forServerUrl) return emptyList()
        val raw = preferences.getString(IMAGE_INDEX, null) ?: return emptyList()
        return runCatching {
            val array = JSONArray(raw)
            buildList(array.length()) {
                for (index in 0 until array.length()) {
                    val item = array.getJSONObject(index)
                    add(Artwork(item.getString("url"), item.getString("displayPath")))
                }
            }
        }.getOrDefault(emptyList())
    }

    fun saveIndex(serverUrl: String, artwork: List<Artwork>) {
        val array = JSONArray()
        artwork.forEach { image ->
            array.put(
                JSONObject()
                    .put("url", image.url)
                    .put("displayPath", image.displayPath),
            )
        }
        preferences.edit {
            putString(INDEX_SERVER_URL, serverUrl)
            putString(IMAGE_INDEX, array.toString())
        }
    }

    private fun encrypt(plainText: String): String? = runCatching {
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, secretKey())
        val encrypted = cipher.doFinal(plainText.toByteArray(Charsets.UTF_8))
        val combined = ByteArray(cipher.iv.size + encrypted.size)
        cipher.iv.copyInto(combined)
        encrypted.copyInto(combined, cipher.iv.size)
        Base64.encodeToString(combined, Base64.NO_WRAP)
    }.getOrNull()

    private fun decrypt(encoded: String?): String? {
        if (encoded == null) return null
        return runCatching {
            val combined = Base64.decode(encoded, Base64.NO_WRAP)
            require(combined.size > IV_LENGTH)
            val iv = combined.copyOfRange(0, IV_LENGTH)
            val encrypted = combined.copyOfRange(IV_LENGTH, combined.size)
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.DECRYPT_MODE, secretKey(), GCMParameterSpec(128, iv))
            String(cipher.doFinal(encrypted), Charsets.UTF_8)
        }.getOrNull()
    }

    private fun secretKey(): SecretKey {
        val keyStore = KeyStore.getInstance(ANDROID_KEY_STORE).apply { load(null) }
        (keyStore.getKey(KEY_ALIAS, null) as? SecretKey)?.let { return it }

        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEY_STORE).run {
            init(
                KeyGenParameterSpec.Builder(
                    KEY_ALIAS,
                    KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
                )
                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    .build(),
            )
            generateKey()
        }
    }

    private companion object {
        const val PREFERENCES = "first_friday"
        const val SERVER_URL = "server_url"
        const val USERNAME = "username"
        const val PASSWORD = "password"
        const val IMAGE_DURATION_MILLIS = "image_duration_millis"
        const val AUDIO_MODE = "audio_mode"
        const val STATION_ID = "station_id"
        const val RADIO_URL = "radio_url"
        const val INDEX_SERVER_URL = "index_server_url"
        const val IMAGE_INDEX = "image_index"
        const val ANDROID_KEY_STORE = "AndroidKeyStore"
        const val KEY_ALIAS = "first_friday_webdav_password"
        const val TRANSFORMATION = "AES/GCM/NoPadding"
        const val IV_LENGTH = 12
    }
}
