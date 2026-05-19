import Foundation
import SwiftUI

@Observable
final class ImageIndex {
    var images: [WebDAVImage] = []
    var isLoading: Bool = false
    var lastError: String?

    private let cacheURL: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("image_index.json")
    }()

    init() {
        loadFromDisk()
    }

    func refresh(using settings: AppSettings) async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        switch settings.artworkSource {
        case .builtin:
            images = BuiltinPaintings.images
            saveToDisk()
        case .webdav:
            guard let client = settings.makeClient() else {
                lastError = "Invalid server URL"
                return
            }
            do {
                let result = try await client.listAllImages()
                images = result
                saveToDisk()
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    func randomImage(excluding: WebDAVImage? = nil) -> WebDAVImage? {
        guard !images.isEmpty else { return nil }
        if images.count == 1 { return images.first }
        var pick = images.randomElement()!
        var attempts = 0
        while pick == excluding && attempts < 5 {
            pick = images.randomElement()!
            attempts += 1
        }
        return pick
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: cacheURL),
              let decoded = try? JSONDecoder().decode([WebDAVImage].self, from: data)
        else { return }
        images = decoded
    }

    private func saveToDisk() {
        if let data = try? JSONEncoder().encode(images) {
            try? data.write(to: cacheURL)
        }
    }
}
