package com.firstfriday.palefire.ui

import android.app.Application
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.LruCache
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.firstfriday.palefire.data.AudioMode
import com.firstfriday.palefire.data.Artwork
import com.firstfriday.palefire.data.GalleryDefaults
import com.firstfriday.palefire.data.RadioPlayer
import com.firstfriday.palefire.data.RadioStations
import com.firstfriday.palefire.data.ServerSettings
import com.firstfriday.palefire.data.SettingsRepository
import com.firstfriday.palefire.data.WebDavClient
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlin.random.Random

data class GalleryUiState(
    val screen: Screen = Screen.Loading,
    val bitmap: Bitmap? = null,
    val currentArtwork: Artwork? = null,
    val metadataVisible: Boolean = false,
    val message: String? = null,
    val setupServerUrl: String = "",
    val setupUsername: String = "",
    val setupPassword: String = "",
    val setupImageDurationMillis: Long = GalleryDefaults.IMAGE_DURATION_MILLIS,
    val setupAudioMode: AudioMode = AudioMode.STATIONS,
    val setupStationId: String = GalleryDefaults.STATION_ID,
    val setupRadioUrl: String = "",
    val setupCanCancel: Boolean = false,
    val isConnecting: Boolean = false,
    val isAudioConfigured: Boolean = false,
    val isAudioPlaying: Boolean = false,
    val nowPlaying: String? = null,
    val audioError: String? = null,
)

data class SettingsDraft(
    val serverUrl: String,
    val username: String,
    val password: String,
    val imageDurationMillis: Long,
    val audioMode: AudioMode,
    val stationId: String,
    val radioUrl: String,
)

enum class Screen { Loading, Setup, Gallery }

class GalleryViewModel(application: Application) : AndroidViewModel(application) {
    private val repository = SettingsRepository(application)
    private val radioPlayer = RadioPlayer(application)
    private val _state = MutableStateFlow(GalleryUiState())
    val state: StateFlow<GalleryUiState> = _state.asStateFlow()

    private var settings: ServerSettings? = null
    private var client: WebDavClient? = null
    private var images: List<Artwork> = emptyList()
    private val history = ArtworkHistory()
    private val artworkDataCache = object : LruCache<String, ByteArray>(ARTWORK_CACHE_KIB) {
        override fun sizeOf(key: String, value: ByteArray): Int =
            (value.size / 1_024).coerceAtLeast(1)
    }
    private var metadataJob: Job? = null
    private var slideshowJob: Job? = null
    private var imageRequestNumber = 0L
    private var appInForeground = false

    init {
        viewModelScope.launch {
            radioPlayer.state.collect { radioState ->
                _state.update {
                    it.copy(
                        isAudioConfigured = radioState.isConfigured,
                        isAudioPlaying = radioState.isPlaying,
                        nowPlaying = radioState.nowPlaying,
                        audioError = radioState.error,
                    )
                }
            }
        }
        val saved = repository.loadSettings()
        if (saved == null) {
            _state.update { it.copy(screen = Screen.Setup) }
        } else {
            settings = saved
            client = WebDavClient(saved)
            images = repository.loadIndex(saved.serverUrl)
            if (images.isNotEmpty()) {
                showRandomArtwork()
                refreshIndexInBackground()
            } else {
                loadIndex(showErrors = true)
            }
        }
    }

    fun connect(draft: SettingsDraft) {
        if (_state.value.isConnecting) return
        viewModelScope.launch {
            _state.update { it.copy(isConnecting = true, message = null) }
            val candidate = runCatching {
                ServerSettings(
                    serverUrl = WebDavClient.normalizeServerUrl(draft.serverUrl).toASCIIString(),
                    username = draft.username,
                    password = draft.password,
                    imageDurationMillis = draft.imageDurationMillis.takeIf { it > 0 }
                        ?: GalleryDefaults.IMAGE_DURATION_MILLIS,
                    audioMode = draft.audioMode,
                    stationId = RadioStations.find(draft.stationId)?.id
                        ?: GalleryDefaults.STATION_ID,
                    radioUrl = draft.radioUrl.trim(),
                )
            }.getOrElse { error ->
                _state.update {
                    it.copy(isConnecting = false, message = error.message ?: "Invalid server URL")
                }
                return@launch
            }
            val previous = settings
            val artworkSourceIsUnchanged = previous != null &&
                previous.serverUrl == candidate.serverUrl &&
                previous.username == candidate.username &&
                previous.password == candidate.password &&
                images.isNotEmpty()
            if (artworkSourceIsUnchanged) {
                repository.saveSettings(candidate)
                settings = candidate
                if (appInForeground && previous.audioConfigurationDiffersFrom(candidate)) {
                    radioPlayer.start(candidate)
                }
                _state.update {
                    it.copy(
                        screen = Screen.Gallery,
                        isConnecting = false,
                        message = null,
                        metadataVisible = false,
                    )
                }
                scheduleSlideshow()
                return@launch
            }
            val candidateClient = WebDavClient(candidate)
            runCatching { candidateClient.listAllImages() }
                .onSuccess { result ->
                    if (result.isEmpty()) {
                        _state.update {
                            it.copy(isConnecting = false, message = "No supported images found.")
                        }
                        return@onSuccess
                    }
                    repository.saveSettings(candidate)
                    repository.saveIndex(candidate.serverUrl, result)
                    settings = candidate
                    client = candidateClient
                    images = result
                    history.clear()
                    artworkDataCache.evictAll()
                    if (appInForeground) radioPlayer.start(candidate)
                    _state.update {
                        it.copy(
                            screen = Screen.Gallery,
                            isConnecting = false,
                            message = null,
                            metadataVisible = false,
                        )
                    }
                    showRandomArtwork()
                }
                .onFailure { error ->
                    _state.update {
                        it.copy(
                            isConnecting = false,
                            message = error.message ?: "Could not connect to the WebDAV server.",
                        )
                    }
                }
        }
    }

    fun openSettings() {
        val current = settings
        _state.update {
            it.copy(
                screen = Screen.Setup,
                setupServerUrl = current?.serverUrl.orEmpty(),
                setupUsername = current?.username.orEmpty(),
                setupPassword = current?.password.orEmpty(),
                setupImageDurationMillis = current?.imageDurationMillis
                    ?: GalleryDefaults.IMAGE_DURATION_MILLIS,
                setupAudioMode = current?.audioMode ?: AudioMode.STATIONS,
                setupStationId = current?.stationId ?: GalleryDefaults.STATION_ID,
                setupRadioUrl = current?.radioUrl.orEmpty(),
                setupCanCancel = current != null && it.bitmap != null,
                metadataVisible = false,
                message = null,
            )
        }
    }

    fun cancelSettings() {
        if (settings != null) {
            _state.update { it.copy(screen = Screen.Gallery, message = null) }
            scheduleSlideshow()
        }
    }

    fun toggleMetadata() {
        if (_state.value.currentArtwork == null) return
        metadataJob?.cancel()
        val visible = !_state.value.metadataVisible
        _state.update { it.copy(metadataVisible = visible) }
        if (visible) {
            metadataJob = viewModelScope.launch {
                delay(METADATA_DURATION_MILLIS)
                _state.update { it.copy(metadataVisible = false) }
            }
        }
    }

    fun toggleAudio() {
        radioPlayer.togglePlayPause()
        if (_state.value.metadataVisible) {
            metadataJob?.cancel()
            metadataJob = viewModelScope.launch {
                delay(METADATA_DURATION_MILLIS)
                _state.update { it.copy(metadataVisible = false) }
            }
        }
    }

    fun onForeground() {
        if (appInForeground) return
        appInForeground = true
        settings?.let(radioPlayer::start)
    }

    fun onBackground() {
        appInForeground = false
        radioPlayer.stop()
    }

    fun nextArtwork() {
        if (images.isEmpty()) return
        val forwardArtwork = history.nextCandidate()
        if (forwardArtwork == null) {
            showRandomArtwork()
        } else {
            showArtwork(forwardArtwork) { history.commitNext(forwardArtwork) }
        }
    }

    fun previousArtwork() {
        val previousArtwork = history.previousCandidate() ?: return
        showArtwork(previousArtwork) { history.commitPrevious(previousArtwork) }
    }

    fun retry() {
        if (images.isEmpty()) loadIndex(showErrors = true) else nextArtwork()
    }

    private fun loadIndex(showErrors: Boolean) {
        val activeSettings = settings ?: return
        val activeClient = client ?: return
        viewModelScope.launch {
            if (showErrors) _state.update { it.copy(screen = Screen.Loading, message = null) }
            runCatching { activeClient.listAllImages() }
                .onSuccess { result ->
                    if (result.isEmpty()) {
                        _state.update {
                            it.copy(screen = Screen.Loading, message = "No supported images found.")
                        }
                    } else {
                        images = result
                        repository.saveIndex(activeSettings.serverUrl, result)
                        showRandomArtwork()
                    }
                }
                .onFailure { error ->
                    if (showErrors) {
                        _state.update {
                            it.copy(
                                screen = Screen.Loading,
                                message = error.message ?: "Could not load the artwork library.",
                            )
                        }
                    }
                }
        }
    }

    private fun refreshIndexInBackground() {
        val activeSettings = settings ?: return
        val activeClient = client ?: return
        viewModelScope.launch {
            runCatching { activeClient.listAllImages() }.onSuccess { result ->
                if (result.isNotEmpty()) {
                    images = result
                    repository.saveIndex(activeSettings.serverUrl, result)
                }
            }
        }
    }

    private fun showRandomArtwork() {
        val activeClient = client ?: return
        if (images.isEmpty()) return
        val currentUrl = _state.value.currentArtwork?.url
        val candidates = images.filterNot { it.url == currentUrl }.ifEmpty { images }
        val shuffled = candidates.shuffled(Random.Default)
        val requestNumber = ++imageRequestNumber
        slideshowJob?.cancel()
        metadataJob?.cancel()
        _state.update {
            it.copy(screen = Screen.Gallery, metadataVisible = false, message = null)
        }
        viewModelScope.launch {
            var lastError: Throwable? = null
            for (artwork in shuffled.take(MAX_DOWNLOAD_ATTEMPTS)) {
                val bitmap = runCatching {
                    loadArtworkBitmap(activeClient, artwork)
                        ?: error("Android could not decode ${artwork.displayPath}")
                }.onFailure { lastError = it }.getOrNull() ?: continue
                if (requestNumber != imageRequestNumber) return@launch
                _state.update {
                    it.copy(
                        screen = Screen.Gallery,
                        bitmap = bitmap,
                        currentArtwork = artwork,
                        message = null,
                    )
                }
                history.record(artwork)
                scheduleSlideshow()
                return@launch
            }
            if (requestNumber == imageRequestNumber) {
                _state.update {
                    it.copy(message = lastError?.message ?: "Could not load an artwork image.")
                }
            }
        }
    }

    private fun showArtwork(artwork: Artwork, onLoaded: () -> Unit) {
        val activeClient = client ?: return
        val requestNumber = ++imageRequestNumber
        slideshowJob?.cancel()
        metadataJob?.cancel()
        _state.update {
            it.copy(screen = Screen.Gallery, metadataVisible = false, message = null)
        }
        viewModelScope.launch {
            val bitmap = runCatching {
                loadArtworkBitmap(activeClient, artwork)
                    ?: error("Android could not decode ${artwork.displayPath}")
            }.getOrElse { error ->
                if (requestNumber == imageRequestNumber) {
                    _state.update {
                        it.copy(message = error.message ?: "Could not load this artwork image.")
                    }
                }
                return@launch
            }
            if (requestNumber != imageRequestNumber) return@launch
            onLoaded()
            _state.update {
                it.copy(
                    screen = Screen.Gallery,
                    bitmap = bitmap,
                    currentArtwork = artwork,
                    message = null,
                )
            }
            scheduleSlideshow()
        }
    }

    private suspend fun loadArtworkBitmap(
        activeClient: WebDavClient,
        artwork: Artwork,
    ): Bitmap? {
        val data = artworkDataCache.get(artwork.url) ?: activeClient.download(artwork.url).also {
            artworkDataCache.put(artwork.url, it)
        }
        return withContext(Dispatchers.Default) { decodeArtwork(data) }
    }

    private fun scheduleSlideshow() {
        slideshowJob?.cancel()
        slideshowJob = viewModelScope.launch {
            delay(settings?.imageDurationMillis ?: GalleryDefaults.IMAGE_DURATION_MILLIS)
            nextArtwork()
        }
    }

    private fun ServerSettings.audioConfigurationDiffersFrom(other: ServerSettings): Boolean =
        audioMode != other.audioMode || stationId != other.stationId || radioUrl != other.radioUrl

    override fun onCleared() {
        radioPlayer.release()
        super.onCleared()
    }

    private fun decodeArtwork(data: ByteArray): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(data, 0, data.size, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
        var sampleSize = 1
        while (bounds.outWidth / sampleSize > MAX_BITMAP_DIMENSION ||
            bounds.outHeight / sampleSize > MAX_BITMAP_DIMENSION
        ) {
            sampleSize *= 2
        }
        val options = BitmapFactory.Options().apply {
            inSampleSize = sampleSize
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        return BitmapFactory.decodeByteArray(data, 0, data.size, options)
    }

    private companion object {
        const val METADATA_DURATION_MILLIS = 5_000L
        const val MAX_BITMAP_DIMENSION = 3_072
        const val MAX_DOWNLOAD_ATTEMPTS = 8
        const val ARTWORK_CACHE_KIB = 64 * 1_024
    }
}
