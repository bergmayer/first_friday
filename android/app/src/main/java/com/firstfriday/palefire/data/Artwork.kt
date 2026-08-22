package com.firstfriday.palefire.data

data class Artwork(
    val url: String,
    val displayPath: String,
)

enum class AudioMode {
    NONE,
    STATIONS,
    CUSTOM_URL,
}

data class ServerSettings(
    val serverUrl: String,
    val username: String,
    val password: String,
    val imageDurationMillis: Long = GalleryDefaults.IMAGE_DURATION_MILLIS,
    val audioMode: AudioMode = AudioMode.STATIONS,
    val stationId: String = GalleryDefaults.STATION_ID,
    val radioUrl: String = "",
)

object GalleryDefaults {
    const val IMAGE_DURATION_MILLIS = 7 * 60 * 1_000L
    const val STATION_ID = "wfmu"
}
