import Foundation
import Testing
#if canImport(FirstFridayCore)
@testable import FirstFridayCore
#else
@testable import Viewport
#endif

@Suite("Artwork sidecars")
struct ArtworkMetadataTests {
    @Test func liveSchema() {
        let yaml = """
        file: "Northern_Renaissance/altar.jpg"
        title: "The Ghent Altar (detail)"
        artist: "Jan van Eyck"
        year: 1432
        date: "c.1432"
        style: "Northern Renaissance"
        genre: "religious painting"
        wikiart: "https://www.wikiart.org/en/jan-van-eyck/altar"
        """
        #expect(ArtworkMetadata.displayText(from: Data(yaml.utf8)) == "The Ghent Altar (detail)\nJan van Eyck, c.1432\nNorthern Renaissance · religious painting")
        #expect(ArtworkMetadata.displayText(from: Data("year: 1432".utf8)) == "1432")
    }

    @Test func yamlScalars() {
        let yaml = #"""
        title: "Study: \"Blue\" #1"
        artist: 'O''Keeffe'
        year: 1930 # comment
        style: >-
          École de
          Paris
        """#
        #expect(ArtworkMetadata.displayText(from: Data(yaml.utf8)) == "Study: \"Blue\" #1\nO'Keeffe, 1930\nÉcole de Paris")
        #expect(ArtworkMetadata.displayText(from: Data("title: No".utf8)) == "No")
    }

    @Test func invalidAndMissingFields() {
        for yaml in ["", "file: image.jpg", "title: null\nartist: ''", "title: [broken", "- title", "title: " + String(repeating: "a", count: 65536)] {
            #expect(ArtworkMetadata.displayText(from: Data(yaml.utf8)) == nil)
        }
    }

    @Test func recursiveListingExcludesSidecars() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SidecarProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        #if canImport(FirstFridayCore)
        let client = WebDAVClient(baseURL: URL(string: "http://gallery.local/art/")!, username: "reader", password: "secret", session: session)
        let images = try await client.listAllImages()
        #expect(images.map(\.displayPath) == ["sub/painting one.JPG"])
        #else
        let client = FirstFridayWebDAVClient(baseURL: URL(string: "http://gallery.local/art/")!, username: "reader", password: "secret", session: session)
        let images = try await client.listImages()
        #expect(images.map(\.title) == ["sub/painting one.JPG"])
        #endif
        let image = try #require(images.first)
        #expect(await client.metadata(for: image.url) == "A painting\nAn artist, 1900")
        #expect(await client.metadata(for: URL(string: "http://gallery.local/missing.jpg")!) == nil)
    }
}

private final class SidecarProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let url = request.url!
        let body: String
        var status = 200
        if request.value(forHTTPHeaderField: "Authorization") != "Basic cmVhZGVyOnNlY3JldA==" { status = 401 }
        if request.httpMethod == "PROPFIND" {
            let paths = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) == "art" ? ["/art/sub/"] : ["/art/sub/painting%20one.JPG", "/art/sub/painting%20one.JPG.yaml", "/art/sub/other.yml", "/art/sub/notes.txt"]
            body = "<multistatus xmlns=\"DAV:\">" + paths.map {
                "<response><href>\($0)</href><propstat><prop><resourcetype>" + ($0.hasSuffix("/") ? "<collection/>" : "") + "</resourcetype></prop></propstat></response>"
            }.joined() + "</multistatus>"
        } else if url.path == "/art/sub/painting one.JPG.yaml" {
            body = "title: A painting\nartist: An artist\nyear: 1900"
        } else { body = ""; status = 404 }
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
