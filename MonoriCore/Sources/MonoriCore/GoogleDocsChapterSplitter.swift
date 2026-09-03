import Foundation

public struct ImportedChapter: Equatable, Sendable {
    public let title: String
    public let urlString: String
    public let orderIndex: Int
    public let contentHTML: String?

    public init(title: String, urlString: String, orderIndex: Int, contentHTML: String? = nil) {
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
    public let sourceKind: SourceKind
    public let chapters: [ImportedChapter]

    public init(sourceURLString: String, title: String, creatorName: String?,
                sourceKind: SourceKind = .googleDocs, chapters: [ImportedChapter]) {
        self.sourceURLString = sourceURLString
        self.title = title
        self.creatorName = creatorName
        self.sourceKind = sourceKind
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
        + #"特別篇|番外篇|附[錄录]|結[語语]|结[語语]|作者(?:的)?[信話话]|"#
        + #"第[0-9０-９一二三四五六七八九十百千兩两〇零]+[章回節节話话篇卷部幕]|"#
        + #"chapter\s+[0-9]+|ch\.?\s*[0-9]+|prologue|epilogue)"#

    private static let fontSizeRegex = try! NSRegularExpression(
        pattern: #"font-size:\s*(\d+(?:\.\d+)?)\s*pt"#,
        options: .caseInsensitive)

    private static let tabNameRegex = try! NSRegularExpression(
        pattern: #"^Tab\s+\d+$"#,
        options: .caseInsensitive)

    private static let chapterMarkerRegex = try! NSRegularExpression(
        pattern: #"第[0-9０-９一二三四五六七八九十百千兩两〇零]+[章回節节話话篇卷部幕]|特別篇[0-9０-９一二三四五六七八九十〇零]*|番外篇?[0-9０-９一二三四五六七八九十〇零]+|chapter\s+[0-9]+"#,
        options: .caseInsensitive)

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
                                               title: stripTrailingPunctuation(cleanTitle(ns.substring(with: m.range(at: 1))))))
                }
                break
            }
        }

        // 2. Paragraph boundaries whose whole text is a chapter title.
        if let regex = try? NSRegularExpression(pattern: "<p\\b[^>]*>([\\s\\S]*?)</p>",
                                                options: .caseInsensitive) {
            for m in regex.matches(in: body, range: NSRange(location: 0, length: ns.length)) {
                let rawInner = ns.substring(with: m.range(at: 1))
                guard let title = chapterTitleParagraph(rawInner) ?? largeFontTitle(rawInner) else { continue }
                boundaries.append(Boundary(start: m.range.location,
                                           afterEnd: m.range.location + m.range.length,
                                           title: title))
            }
        }

        // 2b. Heading tags at levels step 1 didn't use, whose text is a chapter title.
        for level in 1...6 {
            let hPattern = "<h\(level)\\b[^>]*>([\\s\\S]*?)</h\(level)>"
            guard let hRegex = try? NSRegularExpression(pattern: hPattern, options: .caseInsensitive) else { continue }
            for m in hRegex.matches(in: body, range: NSRange(location: 0, length: ns.length)) {
                let rawInner = ns.substring(with: m.range(at: 1))
                guard let title = chapterTitleParagraph(rawInner) else { continue }
                boundaries.append(Boundary(start: m.range.location,
                                           afterEnd: m.range.location + m.range.length,
                                           title: title))
            }
        }

        guard boundaries.count >= 2 else { return [] }

        // 3. Order by document position; merge overlapping and proximity-paired
        //    boundaries (e.g. a 26pt English title followed immediately by an
        //    11pt Chinese translation of the same chapter).
        boundaries.sort { $0.start < $1.start }
        var ordered: [Boundary] = []
        for b in boundaries {
            if let lastIdx = ordered.indices.last {
                let last = ordered[lastIdx]
                if b.start < last.afterEnd { continue }
                let gap = ns.substring(with: NSRange(location: last.afterEnd,
                                                      length: b.start - last.afterEnd))
                if cleanTitle(gap).isEmpty {
                    let lastHasCJK = last.title.range(of: #"[\u{4E00}-\u{9FFF}]"#,
                                                       options: .regularExpression) != nil
                    let bHasCJK = b.title.range(of: #"[\u{4E00}-\u{9FFF}]"#,
                                                 options: .regularExpression) != nil
                    if bHasCJK && !lastHasCJK {
                        ordered[lastIdx] = Boundary(start: last.start,
                                                    afterEnd: b.afterEnd,
                                                    title: b.title)
                    } else {
                        ordered[lastIdx] = Boundary(start: last.start,
                                                    afterEnd: b.afterEnd,
                                                    title: last.title)
                    }
                    continue
                }
            }
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
        if lower.contains("<a ") { return nil }
        let fullText = cleanTitle(rawInner)
        guard chapterMarkerCount(fullText) <= 1 else { return nil }
        let beforeBr = rawInner.replacingOccurrences(
            of: "<br[\\s\\S]*", with: "", options: [.regularExpression, .caseInsensitive])
        let text = cleanTitle(beforeBr)
        guard !text.isEmpty, text.count <= 120 else { return nil }
        guard let markerRange = text.range(of: chapterTitlePattern,
                                           options: [.regularExpression, .caseInsensitive]) else { return nil }
        // Beyond the conservative length a marker prefix alone is ambiguous:
        // "Chapter 64: Back to..." is a title, "ch49 body content..." is prose.
        // Only a separator right after the marker disambiguates in favor of a title.
        let hasCJK = text.range(of: #"[\u{4E00}-\u{9FFF}]"#, options: .regularExpression) != nil
        if text.count > (hasCJK ? 60 : 40) {
            guard let next = text[markerRange.upperBound...].first,
                  ":：.．—–-".contains(next) else { return nil }
        }
        return stripTrailingPunctuation(text)
    }

    private static func largeFontTitle(_ rawInner: String) -> String? {
        let ns = rawInner as NSString
        guard let sizeMatch = fontSizeRegex.firstMatch(
                in: rawInner,
                range: NSRange(location: 0, length: ns.length)),
              let sizeRange = Range(sizeMatch.range(at: 1), in: rawInner),
              let size = Double(rawInner[sizeRange]),
              size >= 18.0 else { return nil }

        let lower = rawInner.lowercased()
        if lower.contains("<a ") { return nil }
        let beforeBr = rawInner.replacingOccurrences(
            of: "<br[\\s\\S]*", with: "", options: [.regularExpression, .caseInsensitive])
        let text = cleanTitle(beforeBr)
        guard !text.isEmpty else { return nil }
        let nsText = text as NSString
        if tabNameRegex.firstMatch(in: text, range: NSRange(location: 0, length: nsText.length)) != nil {
            return nil
        }
        // REMOVED: Old length check was: guard !text.isEmpty, text.count <= 60 else { return nil }
        // Font-size >= 18pt is sufficient structural signal; no length check needed.
        return stripTrailingPunctuation(text)
    }

    private static func chapterMarkerCount(_ text: String) -> Int {
        let ns = text as NSString
        return chapterMarkerRegex.numberOfMatches(in: text, range: NSRange(location: 0, length: ns.length))
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

    private static func stripTrailingPunctuation(_ text: String) -> String {
        var s = text
        while let last = s.last, "。！？.!?".contains(last) {
            s = String(s.dropLast())
        }
        return s.trimmingCharacters(in: .whitespaces)
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

    /// Kept as an entry point for existing callers and tests; the logic lives in
    /// `HTMLSanitizer` so other importers (slashtw) share it.
    static func sanitize(_ html: String) -> String {
        HTMLSanitizer.sanitize(html)
    }
}
