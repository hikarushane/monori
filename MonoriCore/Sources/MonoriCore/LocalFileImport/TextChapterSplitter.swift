import Foundation

/// Splits a plain-text novel into chapters on heading lines:
/// 「第X章／回／節」 (Arabic or Chinese numerals, no separator required),
/// `Chapter N`, or `Ch. N`. A heading is at most 40 characters and never
/// ends with sentence punctuation. Text before the first heading becomes a
/// 「前言」 chapter; with no headings the whole file is one chapter named
/// after the file.
public enum TextChapterSplitter {
    public static let maxHeadingLength = 40
    public static let forewordTitle = "前言"

    private static let patterns: [NSRegularExpression] = [
        try! NSRegularExpression(pattern: "^第[0-9０-９〇零一二三四五六七八九十百千兩两]+[章回節节]"),
        try! NSRegularExpression(pattern: "^(?:Chapter|CHAPTER)\\s*\\d+(?=$|[\\s:.\\-—–：])"),
        try! NSRegularExpression(pattern: "^Ch\\.\\s*\\d+(?=$|[\\s:.\\-—–：])"),
    ]
    private static let sentenceEnd: Set<Character> = ["。", "！", "？", "!", "?", "…"]
    private static let whitespaceRun = try! NSRegularExpression(pattern: "\\s+")

    public static func isHeading(_ rawLine: String) -> Bool {
        let line = rawLine.trimmingCharacters(in: .whitespaces)
        guard !line.isEmpty, line.count <= maxHeadingLength,
              let last = line.last, !sentenceEnd.contains(last) else { return false }
        let range = NSRange(line.startIndex..., in: line)
        return patterns.contains { $0.firstMatch(in: line, range: range) != nil }
    }

    public static func split(text: String, fileName: String) -> ImportedCollection {
        let sourceURL = LocalFileIdentity.sourceURLString(fileName: fileName)
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.components(separatedBy: "\n")

        var sections: [(title: String, lines: [String])] = []
        var leading: [String] = []
        var sawHeading = false
        for line in lines {
            if isHeading(line) {
                sawHeading = true
                sections.append((title: cleanTitle(line), lines: []))
            } else if sawHeading {
                sections[sections.count - 1].lines.append(line)
            } else {
                leading.append(line)
            }
        }

        // Whether the whole document uses blank lines to separate paragraphs.
        // When it does, a single chapter section that happens to contain no
        // blank line of its own must still be rendered in that same
        // paragraph-joining mode, not PlainTextHTML's "no blank line
        // anywhere" one-paragraph-per-line fallback meant for whole
        // headingless web-novel files.
        let hasBlankLineOverall = hasInteriorBlankLine(lines)

        var bodies: [(title: String, html: String)] = []
        if !sawHeading {
            let html = render(leading, forceParagraphJoin: hasBlankLineOverall)
            if !html.isEmpty {
                bodies.append((LocalFileIdentity.title(fromFileName: fileName), html))
            }
        } else {
            let foreword = render(leading, forceParagraphJoin: hasBlankLineOverall)
            if !foreword.isEmpty { bodies.append((forewordTitle, foreword)) }
            for section in sections {
                let html = render(section.lines, forceParagraphJoin: hasBlankLineOverall)
                if !html.isEmpty { bodies.append((section.title, html)) }
            }
        }

        let chapters = bodies.enumerated().map { index, body in
            ImportedChapter(title: body.title,
                            urlString: LocalFileIdentity.chapterURLString(sourceURLString: sourceURL,
                                                                          orderIndex: index),
                            orderIndex: index,
                            contentHTML: body.html)
        }
        return ImportedCollection(sourceURLString: sourceURL,
                                  title: LocalFileIdentity.title(fromFileName: fileName),
                                  creatorName: nil,
                                  sourceKind: .localFile,
                                  chapters: chapters)
    }

    /// Renders a chapter section's lines. When `forceParagraphJoin` is true
    /// and the section itself has no blank line, a blank line plus a
    /// sentinel paragraph are appended so PlainTextHTML takes its normal
    /// blank-line-based paragraph path (joining the section into one
    /// paragraph) instead of its one-paragraph-per-line fallback; the
    /// sentinel paragraph is then stripped back off.
    private static func render(_ lines: [String], forceParagraphJoin: Bool) -> String {
        guard forceParagraphJoin, !hasInteriorBlankLine(lines) else {
            return PlainTextHTML.render(text: lines.joined(separator: "\n"))
        }
        let sentinel = "\u{0}"
        let sentinelParagraph = "<p>\(sentinel)</p>"
        let text = lines.joined(separator: "\n") + "\n\n" + sentinel
        let rendered = PlainTextHTML.render(text: text)
        if rendered == sentinelParagraph { return "" }
        let suffix = "\n" + sentinelParagraph
        guard rendered.hasSuffix(suffix) else { return rendered }
        return String(rendered.dropLast(suffix.count))
    }

    /// Whether `lines` contains a blank line once leading/trailing blank
    /// lines are trimmed away — mirrors the trimming PlainTextHTML itself
    /// does, so this reflects whether PlainTextHTML would treat the text as
    /// having "at least one blank line" (paragraph-joining mode).
    private static func hasInteriorBlankLine(_ lines: [String]) -> Bool {
        var trimmed = lines.map { $0.trimmingCharacters(in: .whitespaces) }
        while trimmed.first == "" { trimmed.removeFirst() }
        while trimmed.last == "" { trimmed.removeLast() }
        return trimmed.contains { $0.isEmpty }
    }

    static func cleanTitle(_ line: String) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        return whitespaceRun.stringByReplacingMatches(in: trimmed, range: range, withTemplate: " ")
    }
}
