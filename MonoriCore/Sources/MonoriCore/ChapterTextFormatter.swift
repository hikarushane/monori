import Foundation

public struct ChapterTextPresentation: Equatable {
    public let title: String
    public let preview: String?
}

public enum ChapterTextFormatter {
    private static let maxPreviewLength = 150

    public static func presentation(storedTitle: String, urlString: String) -> ChapterTextPresentation {
        let cleaned = normalizedMultiline(storedTitle)
        guard isProbablyContaminatedTitle(cleaned) else {
            return ChapterTextPresentation(title: cleaned.isEmpty ? fallbackTitle(from: urlString) : cleaned,
                                           preview: nil)
        }

        let lines = cleaned.components(separatedBy: "\n").filter { !$0.isEmpty }
        let firstLine = lines.first ?? ""
        let fallback = fallbackTitle(from: urlString)

        let firstLineIsTitle = !firstLine.isEmpty
            && firstLine.count <= 100
            && !looksLikeBodyText(firstLine)

        let title: String
        let previewSource: String
        if firstLineIsTitle {
            title = firstLine
            previewSource = lines.dropFirst().joined(separator: "\n")
        } else {
            let sourceLabel: String = {
                if URLNormalizer.isVocusHost(urlString) { return "Vocus" }
                return "Patreon post"
            }()
            title = !fallback.isEmpty ? fallback : sourceLabel
            previewSource = cleaned
        }

        let preview: String? = previewSource.isEmpty ? nil
            : previewSource.count <= maxPreviewLength ? previewSource
            : String(previewSource.prefix(maxPreviewLength))
        return ChapterTextPresentation(title: title, preview: preview)
    }

    static func looksLikeBodyText(_ text: String) -> Bool {
        if text.contains("。") { return true }
        if text.count > 60, text.contains(". ") { return true }
        return false
    }

    public static func isProbablyContaminatedTitle(_ title: String) -> Bool {
        let cleaned = normalizedMultiline(title)
        let lines = cleaned.components(separatedBy: "\n").filter { !$0.isEmpty }
        if lines.count >= 2 { return true }
        if cleaned.count > 100 { return true }
        if looksLikeBodyText(cleaned) { return true }
        return false
    }

    private static func normalizedMultiline(_ value: String) -> String {
        value
            .components(separatedBy: .newlines)
            .map { $0.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    private static func fallbackTitle(from urlString: String) -> String {
        guard let url = URLNormalizer.normalize(urlString) else { return "" }
        let parts = url.path.split(separator: "/").map(String.init)
        guard let rawSlug = parts.last, !rawSlug.isEmpty else { return "" }
        let withoutNumericID = rawSlug.replacingOccurrences(
            of: #"-?\d{6,}$"#,
            with: "",
            options: .regularExpression)
        let readable = withoutNumericID
            .removingPercentEncoding?
            .replacingOccurrences(of: #"[-_]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return readable ?? ""
    }
}
