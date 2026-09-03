import Foundation

/// Strips active content from an HTML fragment captured off a third-party page
/// before it is stored in the library and later rendered with `loadHTMLString`
/// (which executes scripts). Used by the Google Docs splitter and the slashtw
/// floor importer.
///
/// Regex-based on purpose: the input is a fragment the page itself already
/// rendered, not arbitrary user input, and there is no offline DOM parser in
/// Foundation to hand it to. Anything that could run code or navigate is
/// removed; ordinary markup (paragraphs, images, links, blockquotes) is left
/// untouched so the reader can style it.
public enum HTMLSanitizer {
    public static func sanitize(_ html: String) -> String {
        var s = html
        // Remove block tags together with their content.
        for tag in ["script", "style", "iframe", "object"] {
            s = s.replacingOccurrences(
                of: "<\(tag)\\b[^>]*>[\\s\\S]*?</\(tag)>",
                with: "", options: [.regularExpression, .caseInsensitive])
        }
        // Remove void or stray tags: <meta> can redirect via http-equiv="refresh",
        // <embed> loads plugins, and an unclosed <script>/<iframe> would survive
        // the block pass above.
        for tag in ["meta", "embed", "script", "style", "iframe", "object"] {
            s = s.replacingOccurrences(of: "</?\(tag)\\b[^>]*/?>",
                                       with: "", options: [.regularExpression, .caseInsensitive])
        }
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
