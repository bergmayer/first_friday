package com.firstfriday.palefire.data

import android.content.Context
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

data class RadioState(
    val isConfigured: Boolean = false,
    val isPlaying: Boolean = false,
    val nowPlaying: String? = null,
    val error: String? = null,
)

class RadioPlayer(context: Context) : Player.Listener {
    private val player = ExoPlayer.Builder(context).build().apply {
        setAudioAttributes(
            AudioAttributes.Builder()
                .setContentType(C.AUDIO_CONTENT_TYPE_MUSIC)
                .setUsage(C.USAGE_MEDIA)
                .build(),
            true,
        )
        addListener(this@RadioPlayer)
    }
    private val _state = MutableStateFlow(RadioState())
    val state: StateFlow<RadioState> = _state.asStateFlow()

    private var fallbackName: String? = null

    fun start(settings: ServerSettings) {
        player.stop()
        player.clearMediaItems()
        fallbackName = null

        val source = when (settings.audioMode) {
            AudioMode.NONE -> null
            AudioMode.STATIONS -> RadioStations.find(settings.stationId)?.let { it.url to it.name }
            AudioMode.CUSTOM_URL -> settings.radioUrl
                .trim()
                .takeIf { it.isNotEmpty() }
                ?.let { normalizeUrl(it) to "Custom stream" }
        }
        if (source == null) {
            _state.value = RadioState()
            return
        }

        fallbackName = source.second
        _state.value = RadioState(isConfigured = true, nowPlaying = fallbackName)
        player.setMediaItem(MediaItem.fromUri(source.first))
        player.prepare()
        player.play()
    }

    fun stop() {
        player.stop()
        player.clearMediaItems()
        fallbackName = null
        _state.value = RadioState()
    }

    fun togglePlayPause() {
        if (!_state.value.isConfigured) return
        val shouldPlay = !_state.value.isPlaying
        player.playWhenReady = shouldPlay
        _state.update { it.copy(isPlaying = shouldPlay) }
    }

    fun release() {
        player.removeListener(this)
        player.release()
    }

    override fun onIsPlayingChanged(isPlaying: Boolean) {
        _state.update { it.copy(isPlaying = isPlaying) }
    }

    override fun onMediaMetadataChanged(mediaMetadata: MediaMetadata) {
        val title = mediaMetadata.title?.toString()?.trim().orEmpty()
        val artist = mediaMetadata.artist?.toString()?.trim().orEmpty()
        val display = listOf(artist, title).filter { it.isNotEmpty() }.joinToString(" — ")
        if (display.isNotEmpty()) {
            _state.update { it.copy(nowPlaying = display) }
        }
    }

    override fun onPlayerError(error: PlaybackException) {
        _state.update {
            it.copy(
                isPlaying = false,
                nowPlaying = fallbackName,
                error = "Could not play this stream.",
            )
        }
    }

    private fun normalizeUrl(value: String): String =
        if (value.startsWith("http://", true) || value.startsWith("https://", true)) {
            value
        } else {
            "http://$value"
        }
}
