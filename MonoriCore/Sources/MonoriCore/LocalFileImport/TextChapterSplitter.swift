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

        // Detected once for the whole document, so a short chapter section
        // (e.g. a two-line 前言 with no blank line of its own) is still
        // rendered in the same paragraph mode as the rest of the file,
        // rather than PlainTextHTML re-detecting layout per section.
        let layout = PlainTextHTML.detectLayout(of: normalized)

        var bodies: [(title: String, html: String)] = []
        if !sawHeading {
            let html = PlainTextHTML.render(text: leading.joined(separator: "\n"), layout: layout)
            if !html.isEmpty {
                bodies.append((LocalFileIdentity.title(fromFileName: fileName), html))
            }
        } else {
            let foreword = PlainTextHTML.render(text: leading.joined(separator: "\n"), layout: layout)
            if !foreword.isEmpty { bodies.append((forewordTitle, foreword)) }
            for section in sections {
                let html = PlainTextHTML.render(text: section.lines.joined(separator: "\n"), layout: layout)
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

    static func cleanTitle(_ line: String) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        return whitespaceRun.stringByReplacingMatches(in: trimmed, range: range, withTemplate: " ")
    }
}
