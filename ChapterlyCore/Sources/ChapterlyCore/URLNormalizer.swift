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
}
