import Foundation

/// A web address found in text, and where.
public struct DetectedLink {
    public let range: NSRange
    public let url: URL
}

/// Finds web addresses in text. Only http and https links count: the
/// detector gives a bare domain such as "apple.com" an http scheme, and an
/// email address a mailto scheme, which is dropped.
public enum LinkDetector {
    private static let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    public static func links(in text: String) -> [DetectedLink] {
        guard let detector, !text.isEmpty else { return [] }
        let range = NSRange(location: 0, length: (text as NSString).length)
        return detector.matches(in: text, range: range).compactMap { match in
            guard let url = match.url,
                  let scheme = url.scheme?.lowercased(),
                  scheme == "http" || scheme == "https" else { return nil }
            return DetectedLink(range: match.range, url: url)
        }
    }
}
