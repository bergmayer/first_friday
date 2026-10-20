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
    @State private var draftAlwaysShowInfo = false
    @State private var draftImageDuration: TimeInterval = 420
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
                        Toggle("Always Show Info", isOn: $draftAlwaysShowInfo)
                        NavigationLink {
                            ImageDurationPicker(selection: $draftImageDuration)
                        } label: {
                            HStack {
                                Text("Image Duration")
                                Spacer()
                                Text(SlideshowDuration(rawValue: draftImageDuration)?.label ?? "\(Int(draftImageDuration)) seconds")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Section("Audio") {
                        ForEach([AudioMode.none, .coolStations, .radio]) { mode in
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
                    draftAlwaysShowInfo = settings.alwaysShowInfo
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
        settings.alwaysShowInfo = draftAlwaysShowInfo
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


private enum SlideshowDuration: TimeInterval, CaseIterable, Identifiable {
    case seconds30 = 30
    case minute1 = 60
    case minutes2 = 120
    case minutes5 = 300
    case minutes7 = 420
    case minutes10 = 600
    case minutes30 = 1800

    var id: TimeInterval { rawValue }
    var label: String {
        switch self {
        case .seconds30: "30 seconds"
        case .minute1: "1 minute"
        default: "\(Int(rawValue / 60)) minutes"
        }
    }
}

struct ImageDurationPicker: View {
    @Binding var selection: TimeInterval
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedDuration: SlideshowDuration?

    var body: some View {
        List(SlideshowDuration.allCases) { duration in
            Button {
                selection = duration.rawValue
                dismiss()
            } label: {
                HStack {
                    Text(duration.label)
                    Spacer()
                    if selection == duration.rawValue {
                        Image(systemName: "checkmark")
                            .accessibilityLabel("Selected")
                    }
                }
            }
            .focused($focusedDuration, equals: duration)
        }
        .navigationTitle("Image Duration")
        .onAppear {
            focusedDuration = SlideshowDuration(rawValue: selection) ?? .minutes7
        }
        .onExitCommand { dismiss() }
    }
}
