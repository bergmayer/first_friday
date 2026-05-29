import Foundation
import AVFoundation

@MainActor
@Observable
final class AudioPlayer {
    enum Mode: Equatable {
        case stopped
        case radio
        case error(String)
    }

    var mode: Mode = .stopped
    var nowPlaying: String?

    private var stationName: String?
    private var radioPlayer: AVPlayer?
    private var radioMetadataOutput: AVPlayerItemMetadataOutput?
    private var radioMetadataDelegate: RadioMetadataDelegate?

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
        }
    }

    func stop() async {
        radioPlayer?.pause()
        radioPlayer = nil
        radioMetadataOutput = nil
        radioMetadataDelegate = nil
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
