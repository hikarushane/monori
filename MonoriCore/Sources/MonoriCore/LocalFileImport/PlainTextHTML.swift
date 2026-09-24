import Foundation

/// Turns plain text into the minimal HTML the reader's stored-HTML path
/// expects: one escaped `<p>` per paragraph. Paragraphs are separated by
/// one or more blank lines; single newlines inside a paragraph are soft
/// wraps and become spaces.
public enum PlainTextHTML {
    public static func paragraphs(from text: String) -> [String] {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let blocks = normalized.components(separatedBy: "\n")
        var paragraphs: [String] = []
        var currentLines: [String] = []
        func flush() {
            let joined = currentLines.joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !joined.isEmpty { paragraphs.append(joined) }
            currentLines.removeAll()
        }
        for rawLine in blocks {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { flush() } else { currentLines.append(line) }
        }
        flush()
        return paragraphs
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
