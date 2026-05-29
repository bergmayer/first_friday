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

    @State private var didLoad = false

    @State private var draftArtworkSource: ArtworkSource = .webdav
    @State private var draftServerURL: String = ""
    @State private var draftUsername: String = ""
    @State private var draftPassword: String = ""
    @State private var draftImageDuration: TimeInterval = 120
    @State private var draftAudioMode: AudioMode = .coolStations
    @State private var draftRadioURL: String = ""
    @State private var draftCoolStationID: String = ""
    @State private var draftCoolStationName: String = ""

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
                        Picker("Source", selection: $draftArtworkSource) {
                            ForEach(ArtworkSource.allCases) { Text($0.label).tag($0) }
                        }
                    }

                    if draftArtworkSource == .webdav {
                        Section {
                            TextField("https://example.com/webdav/", text: $draftServerURL)
                                .textContentType(.URL)
                            TextField("Username", text: $draftUsername)
                                .textContentType(.username)
                            SecureField("Password", text: $draftPassword)
                                .textContentType(.password)
                        } header: {
                            Text("WebDAV Server")
                        } footer: {
                            Text("URL points at a WebDAV directory of images. Subfolders are walked recursively.")
                        }
                    }

                    Section("Slideshow") {
                        Picker("Image Duration", selection: $draftImageDuration) {
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
                                draftAudioMode = mode
                            } label: {
                                HStack {
                                    Image(systemName: draftAudioMode == mode
                                          ? "largecircle.fill.circle"
                                          : "circle")
                                    Text(mode.label)
                                    Spacer()
                                }
                            }
                        }

                        if draftAudioMode == .radio {
                            TextField("Stream URL", text: $draftRadioURL)
                                .textContentType(.URL)
                        }

                        if draftAudioMode == .coolStations {
                            NavigationLink {
                                CoolStationPickerView(
                                    selectedID: $draftCoolStationID,
                                    selectedName: $draftCoolStationName
                                )
                            } label: {
                                HStack {
                                    Text("Station")
                                    Spacer()
                                    Text(draftCoolStationName.isEmpty ? "None" : draftCoolStationName)
                                        .foregroundStyle(.secondary)
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
                        .disabled(testing || (draftArtworkSource == .webdav && draftServerURL.isEmpty))

                        if let onCancel {
                            Button("Cancel", action: onCancel)
                        }
                    }
                }
                .navigationTitle("Settings")
                .onAppear {
                    // Load drafts from settings only on first appearance, not
                    // on every re-appear (e.g. returning from a sub-picker).
                    guard !didLoad else { return }
                    didLoad = true
                    draftArtworkSource = settings.artworkSource
                    draftServerURL = settings.serverURL
                    draftUsername = settings.username
                    draftPassword = settings.password
                    draftImageDuration = settings.imageDuration
                    draftAudioMode = settings.audioMode
                    draftRadioURL = settings.radioURL
                    draftCoolStationID = settings.coolStationID
                    draftCoolStationName = settings.coolStationName
                }
            }
        }
        .conditionalExitCommand(onCancel)
    }

    private func saveAndReload() async {
        testing = true
        defer { testing = false }
        settings.artworkSource = draftArtworkSource
        settings.serverURL = draftServerURL.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.username = draftUsername
        settings.password = draftPassword
        settings.imageDuration = draftImageDuration
        settings.audioMode = draftAudioMode
        settings.radioURL = draftRadioURL.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.coolStationID = draftCoolStationID
        settings.coolStationName = draftCoolStationName

        if settings.artworkSource == .builtin {
            await index.refresh(using: settings)
            onSave()
            return
        }

        guard settings.makeClient() != nil else {
            testResult = "Invalid URL"
            return
        }
        await index.refresh(using: settings)
        if let err = index.lastError {
            testResult = "Error: \(err)"
        } else {
            onSave()
        }
    }
}
