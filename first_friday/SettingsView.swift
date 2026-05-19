import SwiftUI

private extension View {
    @ViewBuilder
    func conditionalExitCommand(_ action: (() -> Void)?) -> some View {
        if let action {
            self.onExitCommand(perform: action)
        } else {
            self
        }
    }
}

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(ImageIndex.self) private var index

    @State private var serverURL: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var radioURL: String = ""
    @State private var playlistShuffle: Bool = false
    @State private var testing = false
    @State private var testResult: String?

    let onSave: () -> Void
    let onCancel: (() -> Void)?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            NavigationStack {
                Form {
                    Section("Artwork") {
                        Picker("Source", selection: Binding(
                            get: { settings.artworkSource },
                            set: { settings.artworkSource = $0 }
                        )) {
                            ForEach(ArtworkSource.allCases) { Text($0.label).tag($0) }
                        }
                    }

                    if settings.artworkSource == .webdav {
                        Section {
                            TextField("https://example.com/webdav/", text: $serverURL)
                                .textContentType(.URL)
                            TextField("Username", text: $username)
                                .textContentType(.username)
                            SecureField("Password", text: $password)
                                .textContentType(.password)
                        } header: {
                            Text("WebDAV Server")
                        } footer: {
                            Text("URL points at a WebDAV directory of images. Subfolders are walked recursively.")
                        }
                    }

                    Section("Slideshow") {
                        Picker("Image Duration", selection: Binding(
                            get: { settings.imageDuration },
                            set: { settings.imageDuration = $0 }
                        )) {
                            Text("30 seconds").tag(TimeInterval(30))
                            Text("1 minute").tag(TimeInterval(60))
                            Text("2 minutes").tag(TimeInterval(120))
                            Text("5 minutes").tag(TimeInterval(300))
                            Text("10 minutes").tag(TimeInterval(600))
                            Text("30 minutes").tag(TimeInterval(1800))
                        }
                    }

                    Section("Audio") {
                        ForEach(AudioMode.allCases) { mode in
                            Button {
                                settings.audioMode = mode
                            } label: {
                                HStack {
                                    Image(systemName: settings.audioMode == mode
                                          ? "largecircle.fill.circle"
                                          : "circle")
                                    Text(mode.label)
                                    Spacer()
                                }
                            }
                        }

                        if settings.audioMode == .coolStations {
                            NavigationLink {
                                CoolStationPickerView()
                            } label: {
                                HStack {
                                    Text("Station")
                                    Spacer()
                                    Text(settings.coolStationName.isEmpty ? "None" : settings.coolStationName)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        if settings.audioMode == .radio {
                            TextField("Stream URL", text: $radioURL)
                                .textContentType(.URL)
                        }

                        if settings.audioMode == .music {
                            ForEach(AppleMusicMode.allCases) { mode in
                                Button {
                                    settings.appleMusicMode = mode
                                } label: {
                                    HStack {
                                        Image(systemName: settings.appleMusicMode == mode
                                              ? "largecircle.fill.circle"
                                              : "circle")
                                        Text(mode.label)
                                        Spacer()
                                    }
                                }
                            }

                            if settings.appleMusicMode == .playlist {
                                NavigationLink {
                                    PlaylistPickerView()
                                } label: {
                                    HStack {
                                        Text("Playlist")
                                        Spacer()
                                        Text(settings.playlistName.isEmpty ? "None" : settings.playlistName)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Toggle("Shuffle", isOn: $playlistShuffle)
                            }

                            if settings.appleMusicMode == .liveStation {
                                NavigationLink {
                                    AppleMusicLiveStationPickerView()
                                } label: {
                                    HStack {
                                        Text("Live Station")
                                        Spacer()
                                        Text(settings.appleMusicLiveStationName.isEmpty ? "None" : settings.appleMusicLiveStationName)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }

                    if let testResult {
                        Section { Text(testResult) }
                    }

                    Section {
                        Button(testing ? "Testing…" : "Save") {
                            Task { await saveAndReload() }
                        }
                        .disabled(testing || (settings.artworkSource == .webdav && serverURL.isEmpty))

                        if let onCancel {
                            Button("Cancel", action: onCancel)
                        }
                    }
                }
                .navigationTitle("Settings")
                .onAppear {
                    serverURL = settings.serverURL
                    username = settings.username
                    password = settings.password
                    radioURL = settings.radioURL
                    playlistShuffle = settings.playlistShuffle
                }
            }
        }
        .conditionalExitCommand(onCancel)
    }

    private func saveAndReload() async {
        testing = true
        defer { testing = false }
        settings.serverURL = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.username = username
        settings.password = password
        settings.radioURL = radioURL.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.playlistShuffle = playlistShuffle

        if settings.artworkSource == .builtin {
            await index.refresh(using: settings)
            onSave()
            return
        }

        guard let client = settings.makeClient() else {
            testResult = "Invalid URL"
            return
        }
        _ = client
        await index.refresh(using: settings)
        if let err = index.lastError {
            testResult = "Error: \(err)"
        } else {
            onSave()
        }
    }
}
