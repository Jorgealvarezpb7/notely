import Foundation

/// The address a page is stored and asked for under: https, without a
/// fragment, with a lowercase host and at least "/" as its path.
public func linkPageKey(for url: URL) -> URL {
    guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return url }
    components.scheme = "https"
    components.fragment = nil
    components.host = components.host?.lowercased()
    if components.path.isEmpty { components.path = "/" }
    return components.url ?? url
}
