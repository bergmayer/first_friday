import Foundation
import AVFoundation
import MusicKit

@MainActor
@Observable
final class AudioPlayer {
    enum Mode: Equatable {
        case stopped
        case radio
        case music
        case error(String)
    }

    var mode: Mode = .stopped
    var nowPlaying: String?

    private var stationName: String?
    private var radioPlayer: AVPlayer?
    private var radioMetadataOutput: AVPlayerItemMetadataOutput?
    private var radioMetadataDelegate: RadioMetadataDelegate?
    private var nowPlayingPoll: Task<Void, Never>?
    private var musicPlayer: ApplicationMusicPlayer { ApplicationMusicPlayer.shared }

    func start(settings: AppSettings) async {
        await stop()
        switch settings.audioMode {
        case .none:
            break
        case .radio:
            let url = settings.radioURL.trimmingCharacters(in: .whitespacesAndNewlines)
            if !url.isEmpty { startRadio(urlString: url, name: nil) }
        case .coolStations:
            if let station = CoolStations.find(id: settings.coolStationID) {
                startRadio(urlString: station.url, name: station.name)
            }
        case .music:
            let pid = settings.playlistID.trimmingCharacters(in: .whitespacesAndNewlines)
            if !pid.isEmpty {
                await startMusic(playlistID: pid, shuffle: settings.playlistShuffle)
            }
        }
    }

    func stop() async {
        nowPlayingPoll?.cancel()
        nowPlayingPoll = nil
        radioPlayer?.pause()
        radioPlayer = nil
        radioMetadataOutput = nil
        radioMetadataDelegate = nil
        let status = musicPlayer.state.playbackStatus
        if status == .playing || status == .paused {
            musicPlayer.stop()
        }
        stationName = nil
        nowPlaying = nil
        mode = .stopped
    }

    private func startRadio(urlString: String, name: String?) {
        var s = urlString
        if !s.lowercased().hasPrefix("http") {
            s = "http://" + s
        }
        guard let url = URL(string: s) else {
            mode = .error("Invalid radio URL")
            return
        }
        stationName = name
        nowPlaying = name
        let item = AVPlayerItem(url: url)
        let output = AVPlayerItemMetadataOutput(identifiers: nil)
        let delegate = RadioMetadataDelegate { [weak self] value in
            guard let self else { return }
            if let value, !value.isEmpty {
                self.nowPlaying = value
            } else {
                self.nowPlaying = self.stationName
            }
        }
        output.setDelegate(delegate, queue: .main)
        item.add(output)
        let player = AVPlayer(playerItem: item)
        player.play()
        radioPlayer = player
        radioMetadataOutput = output
        radioMetadataDelegate = delegate
        mode = .radio
    }

    private func startMusic(playlistID: String, shuffle: Bool) async {
        let auth = await MusicAuthorization.request()
        guard auth == .authorized else {
            mode = .error("Apple Music access not authorized")
            return
        }

        do {
            let id = MusicItemID(playlistID)
            var request = MusicLibraryRequest<Playlist>()
            request.filter(matching: \.id, equalTo: id)
            let response = try await request.response()
            guard let playlist = response.items.first else {
                mode = .error("Selected playlist not found in your library")
                return
            }

            musicPlayer.queue = ApplicationMusicPlayer.Queue(for: [playlist])
            musicPlayer.state.shuffleMode = shuffle ? .songs : .off
            try await musicPlayer.prepareToPlay()
            try await musicPlayer.play()
            mode = .music
            startMusicNowPlayingPoll()
        } catch {
            mode = .error("Music playback failed: \(error.localizedDescription)")
        }
    }

    private func startMusicNowPlayingPoll() {
        nowPlayingPoll?.cancel()
        nowPlayingPoll = Task { [weak self] in
            while !Task.isCancelled {
                await MainActor.run { self?.refreshMusicNowPlaying() }
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private func refreshMusicNowPlaying() {
        guard let entry = musicPlayer.queue.currentEntry else {
            nowPlaying = nil
            return
        }
        let title = entry.title
        if let subtitle = entry.subtitle, !subtitle.isEmpty {
            nowPlaying = "\(subtitle) — \(title)"
        } else {
            nowPlaying = title
        }
    }
}

private final class RadioMetadataDelegate: NSObject, AVPlayerItemMetadataOutputPushDelegate, @unchecked Sendable {
    let onChange: @MainActor @Sendable (String?) -> Void

    init(onChange: @escaping @MainActor @Sendable (String?) -> Void) {
        self.onChange = onChange
    }

    nonisolated func metadataOutput(
        _ output: AVPlayerItemMetadataOutput,
        didOutputTimedMetadataGroups groups: [AVTimedMetadataGroup],
        from track: AVPlayerItemTrack?
    ) {
        let items = groups.flatMap { $0.items }
        let handler = onChange
        Task {
            var latest: String?
            for item in items {
                if let value = try? await item.load(.stringValue) {
                    let s = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !s.isEmpty { latest = s }
                }
            }
            let captured = latest
            await MainActor.run { handler(captured) }
        }
    }
}
