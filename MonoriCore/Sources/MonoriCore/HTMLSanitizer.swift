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
        // <base> re-targets every relative URL, <embed> loads plugins, and an
        // unclosed <script>/<iframe> would survive the block pass above.
        for tag in ["meta", "base", "embed", "script", "style", "iframe", "object"] {
            s = s.replacingOccurrences(of: "</?\(tag)\\b[^>]*/?>",
                                       with: "", options: [.regularExpression, .caseInsensitive])
        }
        // Strip inline event handlers, quoted or unquoted, whether separated from
        // the previous attribute by whitespace, `/`, or nothing after a quoted
        // value (`title="t"onclick=…` is two attributes to an HTML parser).
        s = removingAttributes(pattern: attributeStart + "on[a-z]+\\s*=\\s*(" + attributeValue + ")", in: s)
        // Remove URL attributes whose scheme can run code or smuggle a document.
        s = removingAttributes(
            pattern: attributeStart + "(?:xlink:href|formaction|href|src)\\s*=\\s*(" + attributeValue + ")",
            in: s, where: hasScriptOrDataScheme)
        // Remove inline styles that make outbound requests; plain styles stay.
        s = removingAttributes(pattern: attributeStart + "style\\s*=\\s*(" + attributeValue + ")",
                               in: s, where: loadsRemoteResource)
        return s
    }

    /// An attribute name starts after whitespace, `/`, or a closing quote.
    private static let attributeStart = "(?<=[\\s/\"'])"
    /// Double-quoted, single-quoted, or unquoted (runs to whitespace or `>`).
    private static let attributeValue = "\"[^\"]*\"|'[^']*'|[^\\s>]+"

    /// Removes every match of `pattern` whose capture group 1 (the attribute
    /// value) satisfies `shouldRemove`. Repeats until nothing changes so that a
    /// removal cannot splice the surrounding text into a new dangerous attribute.
    private static func removingAttributes(pattern: String, in html: String,
                                           where shouldRemove: (String) -> Bool = { _ in true }) -> String {
        // Static pattern: a compile failure is a programming error; never fail open.
        let regex = try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        let s = NSMutableString(string: html)
        while true {
            var changed = false
            let matches = regex.matches(in: s as String, range: NSRange(location: 0, length: s.length))
            for match in matches.reversed() where shouldRemove(s.substring(with: match.range(at: 1))) {
                s.replaceCharacters(in: match.range, with: "")
                changed = true
            }
            if !changed { return s as String }
        }
    }

    /// Unquotes and entity-decodes an attribute value, then drops whitespace and
    /// control characters (browsers ignore them inside a URL scheme, so
    /// `java&#9;script:` still runs) and lowercases it.
    private static func normalized(_ rawValue: String) -> String {
        var v = rawValue
        if v.count >= 2, let first = v.first, first == "\"" || first == "'", v.last == first {
            v = String(v.dropFirst().dropLast())
        }
        v = decodingCharacterReferences(v)
        let kept = v.unicodeScalars.filter { $0.value > 0x20 && !(0x7F...0x9F).contains($0.value) }
        return String(String.UnicodeScalarView(kept)).lowercased()
    }

    private static func hasScriptOrDataScheme(_ value: String) -> Bool {
        let v = normalized(value)
        return ["javascript:", "vbscript:", "data:"].contains { v.hasPrefix($0) }
    }

    private static func loadsRemoteResource(_ value: String) -> Bool {
        let v = normalized(value)
        // A backslash is a CSS escape and could spell `url(` indirectly.
        return ["url(", "expression(", "@import", "image-set(", "\\"].contains { v.contains($0) }
    }

    /// Decodes numeric character references (with or without `;`) and the named
    /// references commonly used to hide a scheme.
    private static func decodingCharacterReferences(_ value: String) -> String {
        guard value.contains("&") else { return value }
        let regex = try! NSRegularExpression(pattern: "&(?:#(x[0-9a-f]+|[0-9]+);?|(colon|tab|newline);)",
                                             options: [.caseInsensitive])
        let s = NSMutableString(string: value)
        for match in regex.matches(in: value, range: NSRange(location: 0, length: s.length)).reversed() {
            var decoded = ""
            if match.range(at: 1).location != NSNotFound {
                let digits = s.substring(with: match.range(at: 1)).lowercased()
                let code = digits.hasPrefix("x") ? UInt32(digits.dropFirst(), radix: 16) : UInt32(digits)
                if let code, let scalar = Unicode.Scalar(code) { decoded = String(Character(scalar)) }
            } else {
                switch s.substring(with: match.range(at: 2)).lowercased() {
                case "colon": decoded = ":"
                case "tab": decoded = "\t"
                default: decoded = "\n"
                }
            }
            s.replaceCharacters(in: match.range, with: decoded)
        }
        return s as String
    }
}
