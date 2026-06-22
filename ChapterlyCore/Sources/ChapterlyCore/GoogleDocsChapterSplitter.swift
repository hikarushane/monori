import Foundation

public struct ImportedChapter: Equatable, Sendable {
    public let title: String
    public let urlString: String
    public let orderIndex: Int
    public let contentHTML: String

    public init(title: String, urlString: String, orderIndex: Int, contentHTML: String) {
        self.title = title
        self.urlString = urlString
        self.orderIndex = orderIndex
        self.contentHTML = contentHTML
    }
}

public struct ImportedCollection: Equatable, Sendable {
    public let sourceURLString: String
    public let title: String
    public let creatorName: String?
    public let chapters: [ImportedChapter]

    public init(sourceURLString: String, title: String, creatorName: String?, chapters: [ImportedChapter]) {
        self.sourceURLString = sourceURLString
        self.title = title
        self.creatorName = creatorName
        self.chapters = chapters
    }
}

public enum GoogleDocsChapterSplitter {
    private static let tocTitles: Set<String> = ["目錄", "目次", "contents", "table of contents"]

    public struct RawChapter { let title: String; let html: String }

    public static func split(html: String, docID: String, docTitle: String) -> ImportedCollection {
        let source = "https://docs.google.com/document/d/\(docID)"
        let cleanDocTitle = cleanTitle(docTitle)
        let body = bodyHTML(of: html)

        var raws = detectChapters(body)
        raws = raws.filter { !tocTitles.contains($0.title.lowercased()) && !$0.title.isEmpty }
        raws = dedupedNonEmpty(raws)

        if raws.isEmpty {
            let whole = ImportedChapter(title: cleanDocTitle,
                                        urlString: "\(source)#chapter-0",
                                        orderIndex: 0, contentHTML: sanitize(body))
            return ImportedCollection(sourceURLString: source, title: cleanDocTitle,
                                      creatorName: nil, chapters: [whole])
        }

        let chapters = raws.enumerated().map { i, raw in
            ImportedChapter(title: raw.title,
                            urlString: "\(source)#chapter-\(i)",
                            orderIndex: i,
                            contentHTML: sanitize(raw.html))
        }
        return ImportedCollection(sourceURLString: source, title: cleanDocTitle,
                                  creatorName: nil, chapters: chapters)
    }

    private static func bodyHTML(of html: String) -> String {
        guard let range = html.range(of: "<body[^>]*>", options: [.regularExpression, .caseInsensitive]),
              let end = html.range(of: "</body>", options: .caseInsensitive) else { return html }
        return String(html[range.upperBound..<end.lowerBound])
    }

    /// A chapter title line: CJK 第N章/回/卷… markers, common front/back-matter
    /// labels, or English "Chapter N"/"Prologue". Anchored at the start so prose
    /// that merely mentions a chapter does not match.
    private static let chapterTitlePattern =
        #"^\s*(?:序章?|楔子|引子|前言|尾聲|尾声|後記|后记|番外|外傳|外传|"#
        + #"第[0-9０-９一二三四五六七八九十百千兩两〇零]+[章回節节話话篇卷部幕]|"#
        + #"chapter\s+[0-9]+|ch\.?\s*[0-9]+|prologue|epilogue)"#

    private struct Boundary { let start: Int; let afterEnd: Int; let title: String }

    /// Detects chapter boundaries from real heading tags AND from plain
    /// paragraphs whose entire text is a chapter title (Google Docs where the
    /// author did not apply a Heading paragraph style). Returns [] when fewer
    /// than two boundaries are found, so `split` falls back to a single chapter.
    private static func detectChapters(_ body: String) -> [RawChapter] {
        let ns = body as NSString
        var boundaries: [Boundary] = []

        // 1. Heading boundaries at the shallowest level with >= 2 matches.
        for level in 1...3 {
            let matches = headingMatches(body, level: level)
            if matches.count >= 2 {
                for m in matches {
                    boundaries.append(Boundary(start: m.range.location,
                                               afterEnd: m.range.location + m.range.length,
                                               title: cleanTitle(ns.substring(with: m.range(at: 1)))))
                }
                break
            }
        }

        // 2. Paragraph boundaries whose whole text is a chapter title.
        if let regex = try? NSRegularExpression(pattern: "<p\\b[^>]*>([\\s\\S]*?)</p>",
                                                options: .caseInsensitive) {
            for m in regex.matches(in: body, range: NSRange(location: 0, length: ns.length)) {
                let rawInner = ns.substring(with: m.range(at: 1))
                guard let title = chapterTitleParagraph(rawInner) else { continue }
                boundaries.append(Boundary(start: m.range.location,
                                           afterEnd: m.range.location + m.range.length,
                                           title: title))
            }
        }

        guard boundaries.count >= 2 else { return [] }

        // 3. Order by document position; drop overlapping/near-duplicate
        //    boundaries (e.g. a heading the paragraph scan also caught).
        boundaries.sort { $0.start < $1.start }
        var ordered: [Boundary] = []
        for b in boundaries {
            if let last = ordered.last, b.start < last.afterEnd { continue }
            ordered.append(b)
        }
        guard ordered.count >= 2 else { return [] }

        // 4. Slice content between consecutive title elements.
        return ordered.enumerated().map { idx, b in
            let contentEnd = idx + 1 < ordered.count ? ordered[idx + 1].start : ns.length
            let html = ns.substring(with: NSRange(location: b.afterEnd,
                                                  length: contentEnd - b.afterEnd))
            return RawChapter(title: b.title, html: html)
        }
    }

    private static func headingMatches(_ body: String, level: Int) -> [NSTextCheckingResult] {
        let pattern = "<h\(level)\\b[^>]*>([\\s\\S]*?)</h\(level)>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return [] }
        let ns = body as NSString
        return regex.matches(in: body, range: NSRange(location: 0, length: ns.length))
    }

    /// Returns the cleaned title when a paragraph's whole text is a single
    /// chapter title, else nil. Rejects TOC rows: anything with an anchor or a
    /// line break, anything longer than a title, or any line listing more than
    /// one chapter marker.
    private static func chapterTitleParagraph(_ rawInner: String) -> String? {
        let lower = rawInner.lowercased()
        if lower.contains("<a ") || lower.contains("<br") { return nil }
        let text = cleanTitle(rawInner)
        guard !text.isEmpty, text.count <= 40 else { return nil }
        guard text.range(of: chapterTitlePattern,
                         options: [.regularExpression, .caseInsensitive]) != nil else { return nil }
        guard chapterMarkerCount(text) <= 1 else { return nil }
        return text
    }

    private static func chapterMarkerCount(_ text: String) -> Int {
        let pattern = #"第[0-9０-９一二三四五六七八九十百千兩两〇零]+[章回節节話话篇卷部幕]|chapter\s+[0-9]+"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return 0 }
        let ns = text as NSString
        return regex.numberOfMatches(in: text, range: NSRange(location: 0, length: ns.length))
    }

    private static func bodyTextLength(_ html: String) -> Int {
        cleanTitle(html).count
    }

    private static func isEmptyBody(_ html: String) -> Bool {
        if bodyTextLength(html) > 0 { return false }
        let lower = html.lowercased()
        return !lower.contains("<img") && !lower.contains("<figure") && !lower.contains("<picture")
    }

    private static func normalizedTitle(_ title: String) -> String {
        title.replacingOccurrences(of: #"[\s\u{2060}\u{200B}\u{FEFF}]+"#,
                                   with: "", options: .regularExpression)
    }

    private static func dedupedNonEmpty(_ raws: [RawChapter]) -> [RawChapter] {
        let nonEmpty = raws.filter { !isEmptyBody($0.html) }
        var bestLen: [String: Int] = [:]
        for raw in nonEmpty {
            let key = normalizedTitle(raw.title)
            bestLen[key] = max(bestLen[key] ?? -1, bodyTextLength(raw.html))
        }
        var used: Set<String> = []
        var kept: [RawChapter] = []
        for raw in nonEmpty {
            let key = normalizedTitle(raw.title)
            guard !used.contains(key), bodyTextLength(raw.html) == bestLen[key] else { continue }
            used.insert(key)
            kept.append(raw)
        }
        return kept
    }

    private static func cleanTitle(_ raw: String) -> String {
        var s = raw.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        for (entity, char) in [("&nbsp;", " "), ("&#39;", "'"), ("&quot;", "\""), ("&amp;", "&"),
                               ("&lt;", "<"), ("&gt;", ">")] {
            s = s.replacingOccurrences(of: entity, with: char)
        }
        s = s.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: " - Google 文件", with: "")
        s = s.replacingOccurrences(of: ".docx", with: "")
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func sanitize(_ html: String) -> String {
        var s = html
        // Remove block tags with their content.
        for tag in ["script", "style"] {
            s = s.replacingOccurrences(
                of: "<\(tag)\\b[^>]*>[\\s\\S]*?</\(tag)>",
                with: "", options: [.regularExpression, .caseInsensitive])
        }
        // Remove <meta> tags (can trigger redirects via http-equiv="refresh").
        s = s.replacingOccurrences(of: "<meta\\b[^>]*/?>",
                                   with: "", options: [.regularExpression, .caseInsensitive])
        // Strip inline event handlers.
        s = s.replacingOccurrences(of: "\\son\\w+\\s*=\\s*\"[^\"]*\"",
                                   with: "", options: [.regularExpression, .caseInsensitive])
        s = s.replacingOccurrences(of: "\\son\\w+\\s*=\\s*'[^']*'",
                                   with: "", options: [.regularExpression, .caseInsensitive])
        // Neutralise javascript: and data: URIs in href/src attributes.
        for attr in ["href", "src"] {
            s = s.replacingOccurrences(
                of: "\\b\(attr)\\s*=\\s*\"(javascript|data):[^\"]*\"",
                with: "\(attr)=\"\"", options: [.regularExpression, .caseInsensitive])
            s = s.replacingOccurrences(
                of: "\\b\(attr)\\s*=\\s*'(javascript|data):[^']*'",
                with: "\(attr)=''", options: [.regularExpression, .caseInsensitive])
        }
        return s
    }
}
