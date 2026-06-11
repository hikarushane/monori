import Foundation

public struct ChapterTextPresentation: Equatable {
    public let title: String
    public let preview: String?
}

public enum ChapterTextFormatter {
    public static func presentation(storedTitle: String, urlString: String) -> ChapterTextPresentation {
        let cleaned = normalizedMultiline(storedTitle)
        guard isProbablyContaminatedTitle(cleaned) else {
            return ChapterTextPresentation(title: cleaned.isEmpty ? fallbackTitle(from: urlString) : cleaned,
                                           preview: nil)
        }

        let fallback = fallbackTitle(from: urlString)
        let firstLine = cleaned.components(separatedBy: "\n").first ?? ""
        let title = fallback.isEmpty ? firstLine : fallback
        return ChapterTextPresentation(title: title.isEmpty ? "Patreon post" : title,
                                       preview: cleaned.isEmpty ? nil : cleaned)
    }

    public static func isProbablyContaminatedTitle(_ title: String) -> Bool {
        let cleaned = normalizedMultiline(title)
        let lines = cleaned.components(separatedBy: "\n").filter { !$0.isEmpty }
        if lines.count >= 3 { return true }
        if cleaned.count > 180 { return true }
        if lines.count >= 2, cleaned.count > 80 { return true }
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
