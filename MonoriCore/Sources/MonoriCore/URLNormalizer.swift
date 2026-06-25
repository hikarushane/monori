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

    /// Extracts the document id from any docs.google.com **document** URL form
    /// (`/document/d/<id>`, `/document/u/N/d/<id>`, with or without `/edit`,
    /// `/mobilebasic`, query, or fragment). Returns nil for non-document editors
    /// (Sheets/Slides/Forms/Drawings) and non-docs hosts.
    public static func googleDocID(_ string: String) -> String? {
        guard let url = URL(string: string),
              let host = url.host?.lowercased(), host == "docs.google.com" else { return nil }
        let parts = url.path.split(separator: "/").map(String.init)
        guard parts.first == "document",
              let dIdx = parts.firstIndex(of: "d"), parts.indices.contains(dIdx + 1) else { return nil }
        let id = parts[dIdx + 1]
        return id.isEmpty ? nil : id
    }

    /// Canonical collection key for a Google Doc: scheme+host+/document/d/<id>, no /edit, tab, or fragment.
    public static func canonicalGoogleDocURL(_ string: String) -> String? {
        guard let id = googleDocID(string) else { return nil }
        return "https://docs.google.com/document/d/\(id)"
    }

    /// True when the string is an importable Google Doc URL - any account-prefixed
    /// (`/document/u/N/d/...`), `/edit`, or `/mobilebasic` form under
    /// `docs.google.com/document/...`. Mirrors `googleDocID` so the import banner
    /// appears exactly when `importGoogleDoc` can succeed.
    public static func isGoogleDocURL(_ string: String) -> Bool {
        googleDocID(string) != nil
    }

    // MARK: - AO3

    private static func ao3Host(_ string: String) -> String? {
        guard let url = URL(string: string),
              let host = url.host?.lowercased(),
              host == "archiveofourown.org" || host.hasSuffix(".archiveofourown.org")
        else { return nil }
        return host
    }

    public static func ao3WorkID(_ string: String) -> String? {
        guard ao3Host(string) != nil,
              let url = URL(string: string) else { return nil }
        let parts = url.path.split(separator: "/").map(String.init)
        guard let idx = parts.firstIndex(of: "works"),
              parts.indices.contains(idx + 1) else { return nil }
        let id = parts[idx + 1]
        return !id.isEmpty && id.allSatisfy(\.isNumber) ? id : nil
    }

    public static func ao3ChapterID(_ string: String) -> String? {
        guard ao3Host(string) != nil,
              let url = URL(string: string) else { return nil }
        let parts = url.path.split(separator: "/").map(String.init)
        guard let idx = parts.firstIndex(of: "chapters"),
              parts.indices.contains(idx + 1) else { return nil }
        let id = parts[idx + 1]
        return !id.isEmpty && id.allSatisfy(\.isNumber) ? id : nil
    }

    public static func isAO3WorkURL(_ string: String) -> Bool {
        ao3WorkID(string) != nil
    }

    public static func isAO3SeriesURL(_ string: String) -> Bool {
        guard ao3Host(string) != nil,
              let url = URL(string: string) else { return false }
        let parts = url.path.split(separator: "/").map(String.init)
        guard let idx = parts.firstIndex(of: "series"),
              parts.indices.contains(idx + 1) else { return false }
        return parts[idx + 1].allSatisfy(\.isNumber)
    }

    public static func canonicalAO3WorkURL(_ string: String) -> String? {
        guard let id = ao3WorkID(string) else { return nil }
        return "https://archiveofourown.org/works/\(id)"
    }

    public static func canonicalAO3ChapterURL(_ string: String) -> String? {
        guard let workID = ao3WorkID(string),
              let chapterID = ao3ChapterID(string) else { return nil }
        return "https://archiveofourown.org/works/\(workID)/chapters/\(chapterID)"
    }

    // MARK: - Vocus

    private static func vocusHost(_ string: String) -> String? {
        guard let url = URL(string: string),
              let host = url.host?.lowercased(),
              host == "vocus.cc" || host.hasSuffix(".vocus.cc")
        else { return nil }
        return host
    }

    private static let hexID = try! Regex("[0-9a-f]{24}")

    public static func vocusSalonID(_ string: String) -> String? {
        guard vocusHost(string) != nil,
              let url = URL(string: string) else { return nil }
        let parts = url.path.split(separator: "/").map(String.init)
        guard parts.first == "salon", parts.count >= 2, !parts[1].isEmpty else { return nil }
        return parts[1]
    }

    public static func isVocusRoomURL(_ string: String) -> Bool {
        vocusRoomSlug(string) != nil
    }

    public static func vocusRoomSlug(_ string: String) -> String? {
        guard let salonID = vocusSalonID(string),
              let url = URL(string: string) else { return nil }
        let parts = url.path.split(separator: "/").map(String.init)
        // ["salon", salonID, "room", slug, ...]
        guard parts.count >= 4,
              parts[0] == "salon", parts[1] == salonID,
              parts[2] == "room", !parts[3].isEmpty else { return nil }
        return parts[3]
    }

    public static func isVocusArticleURL(_ string: String) -> Bool {
        vocusArticleID(string) != nil
    }

    public static func vocusArticleID(_ string: String) -> String? {
        guard vocusHost(string) != nil,
              let url = URL(string: string) else { return nil }
        let parts = url.path.split(separator: "/").map(String.init)
        guard parts.count >= 2, parts[0] == "article" else { return nil }
        let id = parts[1]
        return id.count == 24 && id.wholeMatch(of: hexID) != nil ? id : nil
    }

    public static func canonicalVocusRoomURL(_ string: String) -> String? {
        guard let salonID = vocusSalonID(string),
              let slug = vocusRoomSlug(string) else { return nil }
        return "https://vocus.cc/salon/\(salonID)/room/\(slug)"
    }
}
