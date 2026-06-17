import Foundation

public enum URLNormalizer {
    private static let trackingPrefixes = ["utm_", "mc_"]
    private static let trackingExact: Set<String> = ["fan_landing", "ref"]

    public static func normalize(_ url: URL) -> URL? {
        guard var comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = comps.host?.lowercased(),
              host == "patreon.com" || host.hasSuffix(".patreon.com")
        else { return nil }

        comps.scheme = "https"
        comps.host = "www.patreon.com"
        comps.fragment = nil

        if let items = comps.queryItems {
            let kept = items.filter { item in
                let name = item.name.lowercased()
                if trackingExact.contains(name) { return false }
                return !trackingPrefixes.contains { name.hasPrefix($0) }
            }
            comps.queryItems = kept.isEmpty ? nil : kept
        }

        if comps.path.count > 1, comps.path.hasSuffix("/") {
            comps.path = String(comps.path.dropLast())
        }
        if comps.path.isEmpty { comps.path = "/" }

        return comps.url
    }

    public static func normalize(_ string: String) -> URL? {
        guard let url = URL(string: string) else { return nil }
        return normalize(url)
    }

    /// True when the URL is the Patreon home feed (patreon.com/home or the site root).
    public static func isPatreonHome(_ url: URL) -> Bool {
        guard let normalized = normalize(url) else { return false }
        return normalized.path == "/" || normalized.path == "/home"
    }

    public static func patreonPostID(_ string: String) -> String? {
        guard let url = normalize(string) else { return nil }
        let parts = url.path.split(separator: "/").map(String.init)
        guard let postsIndex = parts.firstIndex(of: "posts"),
              parts.indices.contains(postsIndex + 1) else { return nil }
        let slug = parts[postsIndex + 1]
        if slug.allSatisfy(\.isNumber) { return slug }
        guard let range = slug.range(of: #"\d+$"#, options: .regularExpression) else { return nil }
        return String(slug[range])
    }

    /// Extracts the document id from any docs.google.com document URL form.
    public static func googleDocID(_ string: String) -> String? {
        guard let url = URL(string: string),
              let host = url.host?.lowercased(), host == "docs.google.com" else { return nil }
        let parts = url.path.split(separator: "/").map(String.init)
        guard let dIdx = parts.firstIndex(of: "d"), parts.indices.contains(dIdx + 1) else { return nil }
        let id = parts[dIdx + 1]
        return id.isEmpty ? nil : id
    }

    /// Canonical collection key for a Google Doc: scheme+host+/document/d/<id>, no /edit, tab, or fragment.
    public static func canonicalGoogleDocURL(_ string: String) -> String? {
        guard let id = googleDocID(string) else { return nil }
        return "https://docs.google.com/document/d/\(id)"
    }
}
