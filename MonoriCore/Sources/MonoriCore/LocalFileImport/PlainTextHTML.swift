import Foundation

/// Turns plain text into the minimal HTML the reader's stored-HTML path
/// expects: one escaped `<p>` per paragraph. When the text has at least one
/// blank line, paragraphs are separated by blank lines, but within a
/// blank-line-delimited block a newline at a CJK boundary is itself a
/// paragraph break (Chinese prose is essentially never hard-wrapped); only a
/// newline between two non-CJK characters is a soft wrap, joined with a
/// single space. With no blank line at all, every line is its own paragraph
/// (Chinese web-novel TXT layout).
public enum PlainTextHTML {
    /// How a plain-text document marks paragraph boundaries.
    public enum ParagraphLayout: Equatable, Sendable {
        /// One or more blank lines separate paragraphs; single newlines are soft wraps.
        case blankLineSeparated
        /// Every non-empty line is a paragraph (Chinese web-novel TXT layout).
        case onePerLine
    }

    /// Detects the layout of a whole document: after dropping leading and
    /// trailing empty lines, any remaining empty line means blank-line-separated.
    public static func detectLayout(of text: String) -> ParagraphLayout {
        let lines = trimmedLines(of: text)
        return lines.contains(where: \.isEmpty) ? .blankLineSeparated : .onePerLine
    }

    /// Normalizes newlines, trims each line, and drops leading/trailing
    /// empty lines. Shared by `detectLayout` and `paragraphs`.
    private static func trimmedLines(of text: String) -> [String] {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        var lines = normalized.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        while lines.first?.isEmpty == true { lines.removeFirst() }
        while lines.last?.isEmpty == true { lines.removeLast() }
        return lines
    }

    public static func paragraphs(from text: String, layout: ParagraphLayout? = nil) -> [String] {
        let lines = trimmedLines(of: text)
        guard !lines.isEmpty else { return [] }
        let resolvedLayout = layout ?? detectLayout(of: text)
        if resolvedLayout == .onePerLine {
            return lines.filter { !$0.isEmpty }
        }
        var paragraphs: [String] = []
        var current = ""
        for line in lines {
            if line.isEmpty {
                if !current.isEmpty { paragraphs.append(current) }
                current = ""
            } else if current.isEmpty {
                current = line
            } else if let last = current.last, let first = line.first, isCJK(last) || isCJK(first) {
                paragraphs.append(current)   // CJK boundary: the newline is a paragraph break
                current = line
            } else {
                current += " " + line
            }
        }
        if !current.isEmpty { paragraphs.append(current) }
        return paragraphs
    }

    private static func isCJK(_ c: Character) -> Bool {
        guard let v = c.unicodeScalars.first?.value else { return false }
        switch v {
        case 0x2E80...0x9FFF, 0xAC00...0xD7AF, 0xF900...0xFAFF, 0xFF00...0xFFEF, 0x20000...0x2FA1F:
            return true
        default:
            return false
        }
    }

    public static func render(paragraphs: [String]) -> String {
        paragraphs.map { "<p>\(escape($0))</p>" }.joined(separator: "\n")
    }

    public static func render(text: String, layout: ParagraphLayout? = nil) -> String {
        render(paragraphs: paragraphs(from: text, layout: layout))
    }

    public static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
