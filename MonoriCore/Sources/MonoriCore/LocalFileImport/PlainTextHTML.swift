import Foundation

/// Turns plain text into the minimal HTML the reader's stored-HTML path
/// expects: one escaped `<p>` per paragraph. When the text has at least one
/// blank line, paragraphs are separated by one or more blank lines; with no
/// blank line at all, every line is its own paragraph (Chinese web-novel TXT
/// layout). Soft-wrapped lines within a paragraph join without a space at a
/// CJK boundary, and with a single space otherwise.
public enum PlainTextHTML {
    public static func paragraphs(from text: String) -> [String] {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        var lines = normalized.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        while lines.first?.isEmpty == true { lines.removeFirst() }
        while lines.last?.isEmpty == true { lines.removeLast() }
        guard !lines.isEmpty else { return [] }
        // No blank line anywhere: one paragraph per line (Chinese web-novel layout).
        if !lines.contains(where: \.isEmpty) { return lines }
        var paragraphs: [String] = []
        var current = ""
        for line in lines {
            if line.isEmpty {
                if !current.isEmpty { paragraphs.append(current) }
                current = ""
            } else {
                current = current.isEmpty ? line : join(current, line)
            }
        }
        if !current.isEmpty { paragraphs.append(current) }
        return paragraphs
    }

    /// Soft-wrapped lines rejoin without a space at a CJK boundary.
    private static func join(_ a: String, _ b: String) -> String {
        guard let last = a.last, let first = b.first else { return a + b }
        return (isCJK(last) || isCJK(first)) ? a + b : a + " " + b
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

    public static func render(text: String) -> String {
        render(paragraphs: paragraphs(from: text))
    }

    public static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
