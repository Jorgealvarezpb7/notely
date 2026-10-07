import AppKit
import Combine
import CryptoKit
import Foundation
import ImageIO
import NotelyCore

/// A linked page as its card shows it.
public struct LinkPage {
    public let title: String
    public let description: String?
    public let image: NSImage?
    public let icon: NSImage?
}

/// A page's stored information; images are file names in the cache folder.
struct StoredLinkPage: Codable {
    var title: String
    var description: String?
    var image: String?
    var icon: String?
}

/// Downloads a page's head, then its preview image and site icon, saving
/// both into the cache folder.
enum LinkPageFetcher {
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        configuration.httpAdditionalHeaders = [
            // Many sites send a bare app shell to browsers and their
            // page's title, description, and image only to link-preview
            // crawlers, which they recognize by this token.
            "User-Agent": "Notely/0.1 (link preview) facebookexternalhit/1.1",
        ]
        return URLSession(configuration: configuration)
    }()

    /// At most this much of a page is read; the head comes first.
    private static let pageLimit = 1_000_000

    static func fetch(_ url: URL, folder: URL) async -> StoredLinkPage? {
        guard let fetched = await head(of: url) else { return nil }
        let (html, finalURL) = fetched
        let head = PageHead.parse(html, base: finalURL)
        guard let title = head.title else { return nil }
        var page = StoredLinkPage(title: title, description: head.description)
        if let image = head.image {
            // 600 points wide at most, at 2x.
            page.image = await save(image, maxPixels: 1200, folder: folder)
        }
        let fallback = URL(string: "/favicon.ico", relativeTo: finalURL)?.absoluteURL
        for icon in head.icons + [fallback].compactMap({ $0 }) {
            if let name = await save(icon, maxPixels: 64, folder: folder) {
                page.icon = name
                break
            }
        }
        return page
    }

    /// The page's text up to the end of its head, and the address it was
    /// read from after redirects.
    private static func head(of url: URL) async -> (String, URL)? {
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        guard let result = try? await session.bytes(for: request),
              let http = result.1 as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
        let bytes = result.0
        var data = Data()
        let headEnd = Data("</head>".utf8)
        let upperHeadEnd = Data("</HEAD>".utf8)
        do {
            for try await byte in bytes {
                data.append(byte)
                if data.count >= pageLimit { break }
                if data.count % 16_384 == 0,
                   data.range(of: headEnd) != nil || data.range(of: upperHeadEnd) != nil { break }
            }
        } catch {
            if data.isEmpty { return nil }
        }
        var encoding = String.Encoding.utf8
        if let name = http.textEncodingName {
            let cfEncoding = CFStringConvertIANACharSetNameToEncoding(name as CFString)
            if cfEncoding != kCFStringEncodingInvalidId {
                encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cfEncoding))
            }
        }
        guard let html = String(data: data, encoding: encoding) ?? String(data: data, encoding: .isoLatin1)
        else { return nil }
        return (html, http.url ?? url)
    }

    /// Downloads the image at `url`, scales it to `maxPixels` on its long
    /// side at most, and saves it as PNG (with transparency) or JPEG.
    /// Returns the file name, or nil when it cannot be read.
    private static func save(_ url: URL, maxPixels: Int, folder: URL) async -> String? {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
        if let existing = ["png", "jpg"].map({ "\(digest).\($0)" })
            .first(where: { FileManager.default.fileExists(atPath: folder.appendingPathComponent($0).path) }) {
            return existing
        }
        guard let result = try? await session.data(from: url),
              let http = result.1 as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let source = CGImageSourceCreateWithData(result.0 as CFData, nil) else { return nil }
        // Icon files hold several sizes; take the largest.
        var index = 0
        var largest = 0
        for candidate in 0..<CGImageSourceGetCount(source) {
            let properties = CGImageSourceCopyPropertiesAtIndex(source, candidate, nil) as? [CFString: Any]
            let width = properties?[kCGImagePropertyPixelWidth] as? Int ?? 0
            if width > largest {
                largest = width
                index = candidate
            }
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, index, options as CFDictionary) else { return nil }
        let alpha = image.alphaInfo
        let opaque = alpha == .none || alpha == .noneSkipFirst || alpha == .noneSkipLast
        let name = "\(digest).\(opaque ? "jpg" : "png")"
        let file = folder.appendingPathComponent(name)
        guard let destination = CGImageDestinationCreateWithURL(file as CFURL,
                                                                (opaque ? "public.jpeg" : "public.png") as CFString,
                                                                1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image,
                                   [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        return CGImageDestinationFinalize(destination) ? name : nil
    }
}

/// Page information for every link, kept on disk in the Caches folder so
/// later sessions show cards without asking again. Each address is asked
/// for at most once at a time, four addresses at most at once. A failed
/// request is not kept, and not tried again until the next launch.
/// Every property is read and written on the main thread only; a fetch
/// runs off it and hands its result back there, hence `@unchecked`.
public final class LinkPageStore: ObservableObject, @unchecked Sendable {
    /// Posted on the main thread when a page arrives.
    public static let didLoad = Notification.Name("LinkPageStore.didLoad")

    /// Changes when a page arrives, so SwiftUI rows update.
    @Published public private(set) var revision = 0

    private let folder: URL
    private var stored: [String: StoredLinkPage] = [:]
    private var loaded: [String: LinkPage] = [:]
    private var failed: Set<String> = []
    private var pending: Set<String> = []
    private var queue: [URL] = []
    private var running = 0

    private var indexFile: URL { folder.appendingPathComponent("index.json") }

    /// The app's cache folder for link pages.
    public static var defaultFolder: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent("com.alvarezjorge.Notely/LinkPages", isDirectory: true)
    }

    public init(folder: URL = LinkPageStore.defaultFolder) {
        self.folder = folder
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: indexFile),
           let index = try? JSONDecoder().decode([String: StoredLinkPage].self, from: data) {
            stored = index
        }
    }

    /// The address a page is stored and asked for under; see `linkPageKey`.
    public static func key(for url: URL) -> URL {
        linkPageKey(for: url)
    }

    /// The stored page for `url`, or nil while it has not arrived.
    public func page(for url: URL) -> LinkPage? {
        let key = Self.key(for: url).absoluteString
        if let page = loaded[key] { return page }
        guard let entry = stored[key] else { return nil }
        let page = LinkPage(title: entry.title, description: entry.description,
                            image: entry.image.flatMap { NSImage(contentsOf: folder.appendingPathComponent($0)) },
                            icon: entry.icon.flatMap { NSImage(contentsOf: folder.appendingPathComponent($0)) })
        loaded[key] = page
        return page
    }

    /// Asks for `url`'s page unless it is stored, failed this session, or
    /// already asked for.
    public func request(_ url: URL) {
        let key = Self.key(for: url)
        let name = key.absoluteString
        guard stored[name] == nil, !failed.contains(name), !pending.contains(name) else { return }
        pending.insert(name)
        queue.append(key)
        startNext()
    }

    private func startNext() {
        while running < 4, !queue.isEmpty {
            let key = queue.removeFirst()
            running += 1
            let folder = self.folder
            Task.detached {
                let page = await LinkPageFetcher.fetch(key, folder: folder)
                DispatchQueue.main.async { self.finish(key, page: page) }
            }
        }
    }

    private func finish(_ key: URL, page: StoredLinkPage?) {
        running -= 1
        let name = key.absoluteString
        pending.remove(name)
        if let page {
            stored[name] = page
            loaded[name] = nil
            if let data = try? JSONEncoder().encode(stored) {
                try? data.write(to: indexFile, options: .atomic)
            }
            revision += 1
            NotificationCenter.default.post(name: Self.didLoad, object: self)
        } else {
            failed.insert(name)
        }
        startNext()
    }
}
