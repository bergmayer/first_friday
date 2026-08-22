package com.firstfriday.palefire.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.firstfriday.palefire.data.AudioMode
import com.firstfriday.palefire.data.RadioStations
import kotlin.math.abs

@Composable
fun FirstFridayApp(viewModel: GalleryViewModel = viewModel()) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner, viewModel) {
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_START -> viewModel.onForeground()
                Lifecycle.Event.ON_STOP -> viewModel.onBackground()
                else -> Unit
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        if (lifecycleOwner.lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)) {
            viewModel.onForeground()
        }
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
            viewModel.onBackground()
        }
    }

    MaterialTheme {
        Surface(modifier = Modifier.fillMaxSize(), color = Color.Black) {
            when (state.screen) {
                Screen.Loading -> LoadingScreen(
                    message = state.message,
                    onRetry = viewModel::retry,
                    onSettings = viewModel::openSettings,
                )
                Screen.Setup -> SetupScreen(
                    state = state,
                    onConnect = viewModel::connect,
                    onCancel = viewModel::cancelSettings,
                )
                Screen.Gallery -> GalleryScreen(
                    state = state,
                    onTap = viewModel::toggleMetadata,
                    onSwipeForward = viewModel::nextArtwork,
                    onSwipeBack = viewModel::previousArtwork,
                    onAudioToggle = viewModel::toggleAudio,
                    onSettings = viewModel::openSettings,
                    onLongPress = viewModel::openSettings,
                    onRetry = viewModel::retry,
                )
            }
        }
    }
}

@Composable
private fun GalleryScreen(
    state: GalleryUiState,
    onTap: () -> Unit,
    onSwipeForward: () -> Unit,
    onSwipeBack: () -> Unit,
    onAudioToggle: () -> Unit,
    onSettings: () -> Unit,
    onLongPress: () -> Unit,
    onRetry: () -> Unit,
) {
    var horizontalDrag by remember { mutableFloatStateOf(0f) }
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .pointerInput(Unit) {
                detectHorizontalDragGestures(
                    onDragStart = { horizontalDrag = 0f },
                    onHorizontalDrag = { change, amount ->
                        change.consume()
                        horizontalDrag += amount
                    },
                    onDragEnd = {
                        if (abs(horizontalDrag) > 90f) {
                            if (horizontalDrag < 0f) onSwipeForward() else onSwipeBack()
                        }
                        horizontalDrag = 0f
                    },
                    onDragCancel = { horizontalDrag = 0f },
                )
            }
            .combinedClickable(onClick = onTap, onLongClick = onLongPress),
    ) {
        state.bitmap?.let { bitmap ->
            Image(
                bitmap = bitmap.asImageBitmap(),
                contentDescription = state.currentArtwork?.displayPath,
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Fit,
            )
        } ?: CircularProgressIndicator(
            modifier = Modifier.align(Alignment.Center),
            color = Color.White,
        )

        AnimatedVisibility(
            visible = state.metadataVisible && state.currentArtwork != null,
            enter = fadeIn(),
            exit = fadeOut(),
            modifier = Modifier.align(Alignment.Center),
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(14.dp),
                modifier = Modifier
                    .padding(24.dp)
                    .widthIn(max = 760.dp)
                    .background(Color.Black.copy(alpha = 0.68f), RoundedCornerShape(18.dp))
                    .padding(horizontal = 26.dp, vertical = 20.dp),
            ) {
                Text(
                    text = state.currentArtwork?.displayPath.orEmpty(),
                    color = Color.White,
                    fontSize = 24.sp,
                    textAlign = TextAlign.Center,
                    lineHeight = 31.sp,
                )
                state.nowPlaying
                    ?.takeIf { state.isAudioPlaying && it.isNotBlank() }
                    ?.let { nowPlaying ->
                    Text(
                        text = "♫  $nowPlaying",
                        color = Color.White.copy(alpha = 0.88f),
                        fontSize = 18.sp,
                        textAlign = TextAlign.Center,
                    )
                }
                state.audioError?.let { error ->
                    Text(
                        text = error,
                        color = MaterialTheme.colorScheme.error,
                        textAlign = TextAlign.Center,
                    )
                }
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    if (state.isAudioConfigured) {
                        OutlinedButton(onClick = onAudioToggle) {
                            Text(if (state.isAudioPlaying) "Pause music" else "Play music")
                        }
                    }
                    Button(onClick = onSettings) { Text("Settings") }
                }
            }
        }

        state.message?.let { message ->
            Column(
                modifier = Modifier
                    .align(Alignment.Center)
                    .padding(24.dp)
                    .background(Color.Black.copy(alpha = 0.82f), RoundedCornerShape(18.dp))
                    .padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                Text(message, color = Color.White, textAlign = TextAlign.Center)
                Button(onClick = onRetry) { Text("Try another") }
            }
        }
    }
}

@Composable
private fun LoadingScreen(message: String?, onRetry: () -> Unit, onSettings: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize().padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        if (message == null) {
            CircularProgressIndicator(color = Color.White)
            Spacer(Modifier.height(24.dp))
            Text("Loading artwork…", color = Color.White)
        } else {
            Text(message, color = Color.White, textAlign = TextAlign.Center)
            Spacer(Modifier.height(24.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Button(onClick = onRetry) { Text("Retry") }
                OutlinedButton(onClick = onSettings) { Text("Settings") }
            }
        }
    }
}

@Composable
private fun SetupScreen(
    state: GalleryUiState,
    onConnect: (SettingsDraft) -> Unit,
    onCancel: () -> Unit,
) {
    var serverUrl by remember(state.setupServerUrl) { mutableStateOf(state.setupServerUrl) }
    var username by remember(state.setupUsername) { mutableStateOf(state.setupUsername) }
    var password by remember(state.setupPassword) { mutableStateOf(state.setupPassword) }
    var imageDurationMillis by remember(state.setupImageDurationMillis) {
        mutableStateOf(state.setupImageDurationMillis)
    }
    var audioMode by remember(state.setupAudioMode) { mutableStateOf(state.setupAudioMode) }
    var stationId by remember(state.setupStationId) { mutableStateOf(state.setupStationId) }
    var radioUrl by remember(state.setupRadioUrl) { mutableStateOf(state.setupRadioUrl) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 28.dp, vertical = 22.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Column(modifier = Modifier.fillMaxWidth().widthIn(max = 620.dp)) {
            Text("First Friday", color = Color.White, fontSize = 32.sp)
            Spacer(Modifier.height(8.dp))
            Text(
                "Choose an artwork library, slideshow timing, and music.",
                color = Color.White.copy(alpha = 0.72f),
            )

            Spacer(Modifier.height(24.dp))
            Text("Artwork", color = Color.White, fontSize = 20.sp)
            Spacer(Modifier.height(8.dp))
            Text("WebDAV folders are scanned recursively.", color = Color.White.copy(alpha = 0.6f))
            Spacer(Modifier.height(10.dp))
            OutlinedTextField(
                value = serverUrl,
                onValueChange = { serverUrl = it },
                label = { Text("WebDAV URL") },
                placeholder = { Text("http://server.local/art/") },
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri),
                modifier = Modifier.fillMaxWidth(),
            )
            Spacer(Modifier.height(12.dp))
            OutlinedTextField(
                value = username,
                onValueChange = { username = it },
                label = { Text("Username") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            Spacer(Modifier.height(12.dp))
            OutlinedTextField(
                value = password,
                onValueChange = { password = it },
                label = { Text("Password") },
                singleLine = true,
                visualTransformation = PasswordVisualTransformation(),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                modifier = Modifier.fillMaxWidth(),
            )

            Spacer(Modifier.height(26.dp))
            Text("Slideshow", color = Color.White, fontSize = 20.sp)
            Spacer(Modifier.height(10.dp))
            DurationPicker(value = imageDurationMillis, onValueChange = { imageDurationMillis = it })

            Spacer(Modifier.height(26.dp))
            Text("Music", color = Color.White, fontSize = 20.sp)
            Spacer(Modifier.height(8.dp))
            AudioMode.entries.forEach { mode ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .selectable(
                            selected = audioMode == mode,
                            onClick = { audioMode = mode },
                            role = Role.RadioButton,
                        )
                        .padding(vertical = 5.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    RadioButton(selected = audioMode == mode, onClick = null)
                    Text(mode.label, color = Color.White)
                }
            }
            if (audioMode == AudioMode.STATIONS) {
                Spacer(Modifier.height(8.dp))
                StationPicker(stationId = stationId, onValueChange = { stationId = it })
            } else if (audioMode == AudioMode.CUSTOM_URL) {
                Spacer(Modifier.height(8.dp))
                OutlinedTextField(
                    value = radioUrl,
                    onValueChange = { radioUrl = it },
                    label = { Text("Radio stream URL") },
                    placeholder = { Text("https://station.example/live.mp3") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri),
                    modifier = Modifier.fillMaxWidth(),
                )
            }

            state.message?.let {
                Spacer(Modifier.height(14.dp))
                Text(it, color = MaterialTheme.colorScheme.error)
            }
            Spacer(Modifier.height(22.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Button(
                    onClick = {
                        onConnect(
                            SettingsDraft(
                                serverUrl = serverUrl,
                                username = username,
                                password = password,
                                imageDurationMillis = imageDurationMillis,
                                audioMode = audioMode,
                                stationId = stationId,
                                radioUrl = radioUrl,
                            ),
                        )
                    },
                    enabled = serverUrl.isNotBlank() && !state.isConnecting,
                ) {
                    Text(if (state.isConnecting) "Testing…" else "Save & Test")
                }
                if (state.setupCanCancel) {
                    OutlinedButton(onClick = onCancel, enabled = !state.isConnecting) {
                        Text("Cancel")
                    }
                }
            }
            Spacer(Modifier.height(20.dp))
            Text(
                "In the gallery: tap for details and music controls, swipe left for the next work, swipe right to go back, or hold for settings.",
                color = Color.White.copy(alpha = 0.55f),
            )
        }
    }
}

private val AudioMode.label: String
    get() = when (this) {
        AudioMode.NONE -> "No music"
        AudioMode.STATIONS -> "Stations"
        AudioMode.CUSTOM_URL -> "Custom URL"
    }

private data class DurationOption(val millis: Long, val label: String)

private val durationOptions = listOf(
    DurationOption(30_000L, "30 seconds"),
    DurationOption(60_000L, "1 minute"),
    DurationOption(120_000L, "2 minutes"),
    DurationOption(300_000L, "5 minutes"),
    DurationOption(420_000L, "7 minutes"),
    DurationOption(600_000L, "10 minutes"),
    DurationOption(1_800_000L, "30 minutes"),
)

@Composable
private fun DurationPicker(value: Long, onValueChange: (Long) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    val label = durationOptions.firstOrNull { it.millis == value }?.label ?: "7 minutes"
    Box(modifier = Modifier.fillMaxWidth()) {
        OutlinedButton(onClick = { expanded = true }, modifier = Modifier.fillMaxWidth()) {
            Text("Artwork duration: $label")
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            durationOptions.forEach { option ->
                DropdownMenuItem(
                    text = { Text(option.label) },
                    onClick = {
                        onValueChange(option.millis)
                        expanded = false
                    },
                )
            }
        }
    }
}

@Composable
private fun StationPicker(stationId: String, onValueChange: (String) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    val stationName = RadioStations.find(stationId)?.name ?: RadioStations.all.first().name
    Box(modifier = Modifier.fillMaxWidth()) {
        OutlinedButton(onClick = { expanded = true }, modifier = Modifier.fillMaxWidth()) {
            Text("Station: $stationName")
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            RadioStations.all.forEach { station ->
                DropdownMenuItem(
                    text = { Text(station.name) },
                    onClick = {
                        onValueChange(station.id)
                        expanded = false
                    },
                )
            }
        }
    }
}
