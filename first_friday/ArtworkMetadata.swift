import Foundation
import Yams

/// The server stores one flat YAML mapping at <image filename>.yaml.
nonisolated enum ArtworkMetadata {
    static func displayText(from data: Data) -> String? {
        guard data.count <= 64 * 1024,
              let yaml = String(data: data, encoding: .utf8),
              let node = try? Yams.compose(yaml: yaml),
              let mapping = node.mapping else { return nil }
        func field(_ key: String) -> String? {
            guard let value = mapping[Node.scalar(.init(key))],
                  value.tag != Tag(.null),
                  let text = value.scalar?.string.trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty else { return nil }
            return text
        }
        let title = field("title")
        let artist = field("artist")
        let date = field("date") ?? field("year")
        let attribution = [artist, date].compactMap { $0 }.joined(separator: ", ")
        let details = [field("style"), field("genre")].compactMap { $0 }.joined(separator: " · ")
        let lines = [title, attribution, details].compactMap { $0 }.filter { !$0.isEmpty }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }
}
