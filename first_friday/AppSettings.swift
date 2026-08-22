import Foundation
import SwiftUI

enum AudioMode: String, CaseIterable, Identifiable {
    case none
    case radio
    case coolStations

    var id: String { rawValue }
    var label: String {
        switch self {
        case .none:         return "No music"
        case .radio:        return "Custom URL"
        case .coolStations: return "Stations"
        }
    }
}

enum ArtworkSource: String, CaseIterable, Identifiable {
    case webdav
    case builtin

    var id: String { rawValue }
    var label: String {
        switch self {
        case .webdav:  return "WebDAV Server"
        case .builtin: return "Built-in Paintings"
        }
    }
}

@Observable
final class AppSettings {

    var serverURL: String {
        didSet { UserDefaults.standard.set(serverURL, forKey: "serverURL") }
    }
    var username: String {
        didSet { UserDefaults.standard.set(username, forKey: "username") }
    }
    var password: String {
        didSet { Keychain.save(password) }
    }
    var radioURL: String {
        didSet { UserDefaults.standard.set(radioURL, forKey: "radioURL") }
    }
    var audioMode: AudioMode {
        didSet { UserDefaults.standard.set(audioMode.rawValue, forKey: "audioMode") }
    }
    var imageDuration: TimeInterval {
        didSet { UserDefaults.standard.set(imageDuration, forKey: "imageDuration") }
    }
    var artworkSource: ArtworkSource {
        didSet { UserDefaults.standard.set(artworkSource.rawValue, forKey: "artworkSource") }
    }
    var coolStationID: String {
        didSet { UserDefaults.standard.set(coolStationID, forKey: "coolStationID") }
    }
    var coolStationName: String {
        didSet { UserDefaults.standard.set(coolStationName, forKey: "coolStationName") }
    }

    var isConfigured: Bool {
        !serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init() {
        let env = ProcessInfo.processInfo.environment
        let defaults = UserDefaults.standard

        self.serverURL = defaults.string(forKey: "serverURL") ?? env["WEBDAV_URL"] ?? ""

        self.username = defaults.string(forKey: "username")
            ?? env["WEBDAV_USER"] ?? ""
        self.password = Keychain.load()
            ?? env["WEBDAV_PASS"] ?? ""

        self.radioURL = defaults.string(forKey: "radioURL") ?? ""

        let modeRaw = defaults.string(forKey: "audioMode") ?? ""
        self.audioMode = AudioMode(rawValue: modeRaw) ?? .coolStations

        let storedDuration = defaults.double(forKey: "imageDuration")
        self.imageDuration = storedDuration > 0 ? storedDuration : 420

        let sourceRaw = defaults.string(forKey: "artworkSource") ?? ""
        self.artworkSource = ArtworkSource(rawValue: sourceRaw) ?? .webdav

        self.coolStationID = defaults.string(forKey: "coolStationID") ?? "wfmu"
        self.coolStationName = defaults.string(forKey: "coolStationName") ?? "WFMU"
    }

    func makeClient() -> WebDAVClient? {
        var s = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        let lower = s.lowercased()
        if !lower.hasPrefix("http://") && !lower.hasPrefix("https://") {
            s = "http://" + s
        }
        guard var url = URL(string: s) else { return nil }
        if !url.absoluteString.hasSuffix("/") {
            url = URL(string: url.absoluteString + "/") ?? url
        }
        return WebDAVClient(baseURL: url, username: username, password: password)
    }
}
