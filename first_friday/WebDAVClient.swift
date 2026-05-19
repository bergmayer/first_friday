import Foundation

struct WebDAVImage: Hashable, Codable, Sendable {
    let url: URL
    let displayPath: String
}

enum WebDAVError: Error, LocalizedError {
    case requestFailed(Int)
    case parseError
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .requestFailed(let code): return "Server returned status \(code)"
        case .parseError: return "Could not parse server response"
        case .invalidURL: return "Invalid server URL"
        }
    }
}

actor WebDAVClient {
    let baseURL: URL
    private let authHeader: String

    private static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "gif", "heic", "heif", "webp", "bmp", "tiff", "tif"
    ]

    init(baseURL: URL, username: String, password: String) {
        self.baseURL = baseURL
        let creds = Data("\(username):\(password)".utf8).base64EncodedString()
        self.authHeader = "Basic \(creds)"
    }

    func listAllImages() async throws -> [WebDAVImage] {
        var collected: [WebDAVImage] = []
        try await walk(url: baseURL, relativePath: "", into: &collected)
        return collected
    }

    func downloadImage(at url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response)
        return data
    }

    private func walk(url: URL, relativePath: String, into images: inout [WebDAVImage]) async throws {
        let entries = try await propfind(url: url)
        for entry in entries where !entry.isSelf {
            let name = entry.name
            if entry.isCollection {
                let next = relativePath.isEmpty ? name : "\(relativePath)/\(name)"
                try await walk(url: entry.url, relativePath: next, into: &images)
            } else {
                let ext = (name as NSString).pathExtension.lowercased()
                if Self.imageExtensions.contains(ext) {
                    let display = relativePath.isEmpty ? name : "\(relativePath)/\(name)"
                    images.append(WebDAVImage(url: entry.url, displayPath: display))
                }
            }
        }
    }

    private func propfind(url: URL) async throws -> [Entry] {
        var request = URLRequest(url: url)
        request.httpMethod = "PROPFIND"
        request.setValue("1", forHTTPHeaderField: "Depth")
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        request.setValue("application/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(#"""
        <?xml version="1.0" encoding="utf-8"?>
        <propfind xmlns="DAV:"><prop><resourcetype/></prop></propfind>
        """#.utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response)
        return try MultiStatusParser.parse(data: data, requestedURL: url)
    }

    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw WebDAVError.requestFailed(-1)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw WebDAVError.requestFailed(http.statusCode)
        }
    }

    struct Entry: Sendable {
        let url: URL
        let name: String
        let isCollection: Bool
        let isSelf: Bool
    }
}

// MARK: - PROPFIND XML parsing

nonisolated final class MultiStatusParser: NSObject, XMLParserDelegate {
    private let requestedURL: URL
    private var entries: [WebDAVClient.Entry] = []
    private var inResponse = false
    private var hrefBuffer = ""
    private var capturingHref = false
    private var currentHref: String?
    private var currentIsCollection = false

    private init(requestedURL: URL) {
        self.requestedURL = requestedURL
    }

    static func parse(data: Data, requestedURL: URL) throws -> [WebDAVClient.Entry] {
        let delegate = MultiStatusParser(requestedURL: requestedURL)
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        parser.delegate = delegate
        guard parser.parse() else { throw WebDAVError.parseError }
        return delegate.entries
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        switch elementName {
        case "response":
            inResponse = true
            currentHref = nil
            currentIsCollection = false
        case "href" where inResponse:
            capturingHref = true
            hrefBuffer = ""
        case "collection" where inResponse:
            currentIsCollection = true
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if capturingHref { hrefBuffer += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        switch elementName {
        case "href" where inResponse:
            currentHref = hrefBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            capturingHref = false
        case "response":
            if let href = currentHref, let url = resolve(href: href) {
                let name = decodeLastComponent(of: href)
                let isSelf = pathsEqual(url, requestedURL)
                entries.append(.init(url: url, name: name,
                                     isCollection: currentIsCollection, isSelf: isSelf))
            }
            inResponse = false
        default:
            break
        }
    }

    private func resolve(href: String) -> URL? {
        if let abs = URL(string: href), abs.scheme != nil { return abs }
        var components = URLComponents()
        components.scheme = requestedURL.scheme
        components.host = requestedURL.host
        components.port = requestedURL.port
        // href is typically already percent-encoded
        if let parsed = URLComponents(string: href) {
            components.percentEncodedPath = parsed.percentEncodedPath
        } else {
            components.path = href
        }
        return components.url
    }

    private func pathsEqual(_ a: URL, _ b: URL) -> Bool {
        let trim = CharacterSet(charactersIn: "/")
        let ap = (a.path.removingPercentEncoding ?? a.path).trimmingCharacters(in: trim)
        let bp = (b.path.removingPercentEncoding ?? b.path).trimmingCharacters(in: trim)
        return ap == bp
    }

    /// Extract the last path component from a (possibly partly URL-encoded) href
    /// and decode percent escapes using whatever encoding actually yields a
    /// readable string. WebDAV servers vary — modern ones emit UTF-8, but
    /// Windows/IIS-style servers often emit CP1252 or Latin-1.
    private func decodeLastComponent(of href: String) -> String {
        var s = href
        if let q = s.firstIndex(of: "?") { s = String(s[..<q]) }
        if let f = s.firstIndex(of: "#") { s = String(s[..<f]) }
        while s.hasSuffix("/") { s = String(s.dropLast()) }
        if let lastSlash = s.lastIndex(of: "/") {
            s = String(s[s.index(after: lastSlash)...])
        }
        return Self.decodePercent(s)
    }

    static func decodePercent(_ encoded: String) -> String {
        var bytes = Data()
        let chars = Array(encoded)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "%", i + 2 < chars.count,
               let b = UInt8(String(chars[i+1...i+2]), radix: 16) {
                bytes.append(b)
                i += 3
                continue
            }
            if let ascii = c.asciiValue {
                bytes.append(ascii)
            } else {
                bytes.append(contentsOf: Array(String(c).utf8))
            }
            i += 1
        }
        if let s = String(data: bytes, encoding: .utf8), !s.contains("\u{FFFD}") {
            return s
        }
        // Try common single-byte legacy encodings, in order of likelihood.
        let cp437Enc = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.dosLatinUS.rawValue)))
        let cp850Enc = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.dosLatin1.rawValue)))
        for enc in [String.Encoding.windowsCP1252, .macOSRoman, cp437Enc, cp850Enc, .isoLatin1] {
            if let s = String(data: bytes, encoding: enc) {
                return s
            }
        }
        return encoded
    }
}
