import Foundation

/// What the page's `<head>` says about it: title, description, preview
/// image, and site icons, best first.
public struct PageHead {
    public var title: String?
    public var description: String?
    public var image: URL?
    public var icons: [URL] = []

    public init() {}

    private static let tagPattern = try! NSRegularExpression(
        pattern: #"<(meta|link)\b[^>]*>"#, options: [.caseInsensitive])
    private static let attributePattern = try! NSRegularExpression(
        pattern: #"([a-zA-Z_:][-a-zA-Z0-9_:.]*)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'>]+))"#)
    private static let titlePattern = try! NSRegularExpression(
        pattern: #"<title\b[^>]*>([\s\S]*?)</title>"#, options: [.caseInsensitive])
    private static let entityPattern = try! NSRegularExpression(
        pattern: #"&(#[0-9]+|#[xX][0-9a-fA-F]+|[a-zA-Z]+);"#)

    /// Reads the head of `html`, resolving relative addresses against `base`.
    public static func parse(_ html: String, base: URL) -> PageHead {
        var head = html
        if let end = html.range(of: "</head>", options: .caseInsensitive) {
            head = String(html[..<end.lowerBound])
        }
        let text = head as NSString
        var meta: [String: String] = [:]
        var touchIcons: [URL] = []
        var icons: [URL] = []
        for match in tagPattern.matches(in: head, range: NSRange(location: 0, length: text.length)) {
            let tag = text.substring(with: match.range)
            let attributes = Self.attributes(of: tag)
            if text.substring(with: match.range(at: 1)).lowercased() == "meta" {
                guard let key = (attributes["property"] ?? attributes["name"] ?? attributes["itemprop"])?.lowercased(),
                      let content = attributes["content"], meta[key] == nil else { continue }
                meta[key] = content
            } else {
                guard let rel = attributes["rel"]?.lowercased(), let href = attributes["href"],
                      let url = Self.url(href, base: base) else { continue }
                let tokens = rel.split(separator: " ")
                if tokens.contains(where: { $0.hasPrefix("apple-touch-icon") }) {
                    touchIcons.append(url)
                } else if tokens.contains("icon") {
                    icons.append(url)
                }
            }
        }
        var result = PageHead()
        var pageTitle: String?
        if let match = titlePattern.firstMatch(in: head, range: NSRange(location: 0, length: text.length)) {
            pageTitle = text.substring(with: match.range(at: 1))
        }
        result.title = [meta["og:title"], meta["twitter:title"], pageTitle].lazy.compactMap { $0.map(Self.clean) }
            .first { !$0.isEmpty }
        result.description = [meta["og:description"], meta["twitter:description"], meta["description"]].lazy
            .compactMap { $0.map(Self.clean) }.first { !$0.isEmpty }
        result.image = [meta["og:image:secure_url"], meta["og:image"], meta["og:image:url"],
                        meta["twitter:image"], meta["twitter:image:src"]].lazy
            .compactMap { $0.flatMap { Self.url($0, base: base) } }.first
        result.icons = touchIcons + icons
        return result
    }

    private static func attributes(of tag: String) -> [String: String] {
        let text = tag as NSString
        var result: [String: String] = [:]
        for match in attributePattern.matches(in: tag, range: NSRange(location: 0, length: text.length)) {
            let name = text.substring(with: match.range(at: 1)).lowercased()
            let value = (2...4).lazy.map { match.range(at: $0) }.first { $0.location != NSNotFound }
                .map { text.substring(with: $0) } ?? ""
            if result[name] == nil { result[name] = value }
        }
        return result
    }

    /// An http or https address from an attribute, made absolute. http is
    /// asked for as https: App Transport Security refuses plain http.
    private static func url(_ value: String, base: URL) -> URL? {
        let trimmed = decodeEntities(value).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed, relativeTo: base)?.absoluteURL,
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return nil }
        return linkPageKey(for: url)
    }

    /// Entities decoded and runs of white space made one space.
    private static func clean(_ value: String) -> String {
        decodeEntities(value).split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static let namedEntities: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " ",
        "hellip": "…", "mdash": "—", "ndash": "–", "lsquo": "‘", "rsquo": "’",
        "ldquo": "“", "rdquo": "”", "copy": "©", "reg": "®", "trade": "™",
    ]

    static func decodeEntities(_ value: String) -> String {
        guard value.contains("&") else { return value }
        let text = value as NSString
        var result = ""
        var last = 0
        for match in entityPattern.matches(in: value, range: NSRange(location: 0, length: text.length)) {
            result += text.substring(with: NSRange(location: last, length: match.range.location - last))
            let name = text.substring(with: match.range(at: 1))
            var decoded: String?
            if name.hasPrefix("#x") || name.hasPrefix("#X") {
                decoded = UInt32(name.dropFirst(2), radix: 16).flatMap { Unicode.Scalar($0) }.map { String($0) }
            } else if name.hasPrefix("#") {
                decoded = UInt32(name.dropFirst()).flatMap { Unicode.Scalar($0) }.map { String($0) }
            } else {
                decoded = namedEntities[name.lowercased()]
            }
            result += decoded ?? text.substring(with: match.range)
            last = NSMaxRange(match.range)
        }
        result += text.substring(from: last)
        return result
    }
}
