import Foundation

enum BuiltinPaintings {
    struct Entry {
        let resource: String
        let displayPath: String
        let year: String
    }

    static let entries: [Entry] = [
        .init(resource: "mona-lisa",      displayPath: "Leonardo da Vinci/Mona Lisa", year: "c. 1503–1519"),
        .init(resource: "starry-night",   displayPath: "Vincent van Gogh/The Starry Night", year: "1889"),
        .init(resource: "great-wave",     displayPath: "Katsushika Hokusai/The Great Wave off Kanagawa", year: "c. 1831"),
        .init(resource: "pearl-earring",  displayPath: "Johannes Vermeer/Girl with a Pearl Earring", year: "c. 1665"),
        .init(resource: "birth-of-venus", displayPath: "Sandro Botticelli/The Birth of Venus", year: "c. 1484–1486"),
        .init(resource: "the-kiss",       displayPath: "Gustav Klimt/The Kiss", year: "1907–1908"),
    ]

    static func metadata(for url: URL) -> String? {
        guard url.isFileURL,
              let entry = entries.first(where: { $0.resource == url.deletingPathExtension().lastPathComponent }) else { return nil }
        let parts = entry.displayPath.split(separator: "/", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return entry.displayPath }
        return "\(parts[1])\n\(parts[0]), \(entry.year)"
    }

    static let images: [WebDAVImage] = entries.compactMap { entry in
        guard let url = Bundle.main.url(forResource: entry.resource, withExtension: "jpg") else {
            return nil
        }
        return WebDAVImage(url: url, displayPath: entry.displayPath)
    }
}
