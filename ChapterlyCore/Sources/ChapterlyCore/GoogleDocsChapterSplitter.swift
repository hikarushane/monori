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

        var raws = splitByHeading(body)
        raws = raws.filter { !tocTitles.contains($0.title.lowercased()) && !$0.title.isEmpty }

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

    private static func splitByHeading(_ body: String) -> [RawChapter] {
        for level in 1...3 {
            let chapters = tokenize(body, level: level)
            if chapters.count >= 2 { return chapters }
        }
        return []
    }

    private static func tokenize(_ body: String, level: Int) -> [RawChapter] {
        let pattern = "<h\(level)\\b[^>]*>([\\s\\S]*?)</h\(level)>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return [] }
        let ns = body as NSString
        let matches = regex.matches(in: body, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return [] }

        var result: [RawChapter] = []
        for (idx, m) in matches.enumerated() {
            let title = cleanTitle(ns.substring(with: m.range(at: 1)))
            let contentStart = m.range.location + m.range.length
            let contentEnd = idx + 1 < matches.count ? matches[idx + 1].range.location : ns.length
            let content = ns.substring(with: NSRange(location: contentStart, length: contentEnd - contentStart))
            result.append(RawChapter(title: title, html: content))
        }
        return result
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
