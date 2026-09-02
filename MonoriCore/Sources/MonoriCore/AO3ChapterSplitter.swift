import Foundation

public enum AO3ChapterSplitter {
    public struct NavigateEntry: Equatable, Sendable {
        public let title: String
        public let chapterPath: String
        public let dateText: String?
    }

    public struct FetchedChapterContent: Equatable, Sendable {
        public let entry: NavigateEntry
        public let orderIndex: Int
        public let contentHTML: String
    }

    /// Fetches chapter pages sequentially. Every request after the first is
    /// paced even when an earlier request failed, so a transient failure does
    /// not turn the remainder of an import into an unthrottled request burst.
    public static func fetchChapterContents(
        entries: [NavigateEntry],
        waitBetweenRequests: () async -> Void,
        fetchPage: (String) async -> String?,
        didStartRequest: (Int) -> Void = { _ in }
    ) async -> [FetchedChapterContent] {
        var fetched: [FetchedChapterContent] = []

        for (index, entry) in entries.enumerated() {
            if index > 0 {
                await waitBetweenRequests()
            }
            didStartRequest(index + 1)
            guard let page = await fetchPage(entry.chapterPath),
                  let content = extractChapterContent(html: page) else { continue }
            fetched.append(FetchedChapterContent(
                entry: entry, orderIndex: index, contentHTML: content))
        }

        return fetched
    }

    // MARK: - Navigate page parsing

    /// Parses an AO3 `/works/:id/navigate` page and returns one entry per chapter.
    public static func parseNavigatePage(html: String) -> [NavigateEntry] {
        // Find the <ol class="chapter index …"> list
        guard let listStart = html.range(of: #"<ol[^>]*class="chapter index[^"]*"[^>]*>"#,
                                          options: .regularExpression),
              let listEnd = html[listStart.upperBound...].range(of: "</ol>")
        else { return [] }

        let listHTML = String(html[listStart.upperBound..<listEnd.lowerBound])

        let liPattern   = #"<li[^>]*>([\s\S]*?)</li>"#
        let linkPattern = #"<a\s+href="(/works/\d+/chapters/\d+)"[^>]*>\s*([\s\S]*?)\s*</a>"#
        let datePattern = #"<span\s+class="datetime">\s*\((.*?)\)\s*</span>"#

        guard let liRegex   = try? NSRegularExpression(pattern: liPattern,   options: []),
              let linkRegex = try? NSRegularExpression(pattern: linkPattern,  options: []),
              let dateRegex = try? NSRegularExpression(pattern: datePattern,  options: [])
        else { return [] }

        let nsListHTML = listHTML as NSString
        let liMatches  = liRegex.matches(in: listHTML,
                                          range: NSRange(location: 0, length: nsListHTML.length))
        var entries: [NavigateEntry] = []

        for liMatch in liMatches {
            let liContent = nsListHTML.substring(with: liMatch.range(at: 1))
            let nsLi      = liContent as NSString
            let liRange   = NSRange(location: 0, length: nsLi.length)

            guard let linkMatch = linkRegex.firstMatch(in: liContent, range: liRange) else { continue }

            let path     = nsLi.substring(with: linkMatch.range(at: 1))
            let rawTitle = nsLi.substring(with: linkMatch.range(at: 2))
            let title    = stripHTML(rawTitle).decodingHTMLEntities

            var dateText: String?
            if let dateMatch = dateRegex.firstMatch(in: liContent, range: liRange) {
                dateText = nsLi.substring(with: dateMatch.range(at: 1))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }

            entries.append(NavigateEntry(title: title, chapterPath: path, dateText: dateText))
        }

        return entries
    }

    // MARK: - Chapter content extraction

    /// Extracts the inner HTML of `<div class="userstuff …">` from an AO3 chapter page.
    /// Returns `nil` when no such element is found.
    public static func extractChapterContent(html: String) -> String? {
        guard let openRange = html.range(of: #"<div[^>]*class="userstuff[^"]*"[^>]*>"#,
                                          options: .regularExpression) else { return nil }

        var depth = 1
        var pos   = openRange.upperBound

        while pos < html.endIndex && depth > 0 {
            let remaining = html[pos...]
            let nextOpen  = remaining.range(of: "<div", options: .caseInsensitive)
            let nextClose = remaining.range(of: "</div>", options: .caseInsensitive)

            switch (nextOpen, nextClose) {
            case let (open?, close?) where open.lowerBound < close.lowerBound:
                depth += 1
                pos = open.upperBound
            case let (_, close?):
                depth -= 1
                if depth == 0 {
                    let content = String(html[openRange.upperBound..<close.lowerBound])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    return content.isEmpty ? nil : content
                }
                pos = close.upperBound
            default:
                return nil
            }
        }
        return nil
    }

    // MARK: - Helpers

    private static func stripHTML(_ string: String) -> String {
        string.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - HTML entity decoding

private extension String {
    var decodingHTMLEntities: String {
        var result = self
        let entities: [(String, String)] = [
            ("&amp;",  "&"),
            ("&lt;",   "<"),
            ("&gt;",   ">"),
            ("&quot;", "\""),
            ("&#39;",  "'"),
            ("&apos;", "'"),
            ("&#x27;", "'"),
            ("&nbsp;", " "),
        ]
        for (entity, char) in entities {
            result = result.replacingOccurrences(of: entity, with: char)
        }
        return result
    }
}
