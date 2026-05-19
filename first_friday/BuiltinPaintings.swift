import Foundation

enum BuiltinPaintings {
    struct Entry {
        let resource: String
        let displayPath: String
    }

    static let entries: [Entry] = [
        .init(resource: "mona-lisa",      displayPath: "Leonardo da Vinci/Mona Lisa"),
        .init(resource: "starry-night",   displayPath: "Vincent van Gogh/The Starry Night"),
        .init(resource: "great-wave",     displayPath: "Katsushika Hokusai/The Great Wave off Kanagawa"),
        .init(resource: "pearl-earring",  displayPath: "Johannes Vermeer/Girl with a Pearl Earring"),
        .init(resource: "birth-of-venus", displayPath: "Sandro Botticelli/The Birth of Venus"),
        .init(resource: "the-kiss",       displayPath: "Gustav Klimt/The Kiss"),
    ]

    static let images: [WebDAVImage] = entries.compactMap { entry in
        guard let url = Bundle.main.url(forResource: entry.resource, withExtension: "jpg") else {
            return nil
        }
        return WebDAVImage(url: url, displayPath: entry.displayPath)
    }
}
