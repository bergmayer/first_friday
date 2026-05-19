import SwiftUI
import MusicKit

struct PlaylistPickerView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var playlists: [Playlist] = []
    @State private var authStatus: MusicAuthorization.Status = .notDetermined
    @State private var loading = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if loading {
                ProgressView("Loading playlists…")
            } else if authStatus == .denied || authStatus == .restricted {
                ContentUnavailableView {
                    Label("Apple Music access denied", systemImage: "music.note")
                } description: {
                    Text("Grant access in tvOS Settings → Privacy → Apple Music.")
                }
            } else if let errorMessage {
                ContentUnavailableView {
                    Label("Could not load playlists", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                }
            } else if playlists.isEmpty {
                ContentUnavailableView {
                    Label("No playlists found", systemImage: "music.note.list")
                } description: {
                    Text("This Apple Music account doesn't have any playlists.")
                }
            } else {
                List {
                    if !settings.playlistID.isEmpty {
                        Section {
                            Button("Clear selection") {
                                settings.playlistID = ""
                                settings.playlistName = ""
                                dismiss()
                            }
                        }
                    }
                    Section("Your Playlists") {
                        ForEach(playlists, id: \.id) { playlist in
                            Button {
                                select(playlist)
                            } label: {
                                HStack {
                                    Text(playlist.name)
                                    Spacer()
                                    if playlist.id.rawValue == settings.playlistID {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Select Playlist")
        .task { await load() }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        authStatus = await MusicAuthorization.request()
        guard authStatus == .authorized else { return }
        do {
            let request = MusicLibraryRequest<Playlist>()
            let response = try await request.response()
            playlists = Array(response.items)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func select(_ playlist: Playlist) {
        settings.playlistID = playlist.id.rawValue
        settings.playlistName = playlist.name
        dismiss()
    }
}
