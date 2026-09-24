import Foundation

/// Decodes a text file's bytes, trying the encodings Chinese-language
/// novels actually ship in: UTF-8, UTF-16 with BOM, Big5, GB18030.
/// UTF-8/UTF-16 win on the first successful decode; between Big5 and
/// GB18030 (whose byte ranges overlap heavily) the most plausible-looking
/// decode wins — see `plausibilityScore`.
public enum TextEncodingDetector {
    public static func decode(_ data: Data) -> String? {
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            return String(data: data.dropFirst(3), encoding: .utf8)
        }
        if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]) {
            return String(data: data, encoding: .utf16)
        }
        if let s = String(data: data, encoding: .utf8) { return s }

        // Big5 and GB18030 share almost the entire lead/trail byte range, so
        // a byte string that is valid in one is very often also valid
        // (round-trips cleanly) in the other, just mapping to different,
        // unrelated characters. Trying encodings in a fixed order and
        // stopping at the first successful decode is not enough to tell
        // them apart. Instead, decode with every candidate that round-trips
        // cleanly and keep the one that produces the fewest characters
        // outside common CJK ranges — a wrong-encoding decode tends to
        // surface stray Latin/symbol/box-drawing characters mixed into the
        // text.
        let candidates = [big5, gb18030].compactMap { strictlyDecode(data, as: $0) }
        return candidates.min { plausibilityScore($0) < plausibilityScore($1) }
    }

    /// `String(data:encoding:)` for these legacy CJK encodings is lenient:
    /// it can "succeed" on bytes that belong to a different encoding,
    /// silently producing mojibake instead of failing. Round-tripping the
    /// decoded string back through the same encoding and comparing bytes
    /// rejects those false-positive decodes.
    private static func strictlyDecode(_ data: Data, as encoding: String.Encoding) -> String? {
        guard let s = String(data: data, encoding: encoding),
              let roundTripped = s.data(using: encoding),
              roundTripped == data
        else { return nil }
        return s
    }

    /// Lower is more plausible: counts characters that are not ASCII,
    /// not CJK Unified Ideographs, and not common CJK punctuation/fullwidth
    /// forms. A wrong-encoding decode tends to produce more of these.
    private static func plausibilityScore(_ s: String) -> Int {
        s.unicodeScalars.reduce(0) { count, scalar in
            let v = scalar.value
            let isPlausible = scalar.isASCII
                || (0x4E00...0x9FFF).contains(v)   // CJK Unified Ideographs
                || (0x3400...0x4DBF).contains(v)   // CJK Unified Ideographs Extension A
                || (0x3000...0x303F).contains(v)   // CJK punctuation
                || (0xFF00...0xFFEF).contains(v)   // Halfwidth/Fullwidth forms
                || (0x2000...0x206F).contains(v)   // General Punctuation (“ ” ‘ ’ … — etc.)
                || v == 0x00B7                     // · (middle dot)
            return count + (isPlausible ? 0 : 1)
        }
    }

    private static let big5 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(
        CFStringEncoding(CFStringEncodings.big5_HKSCS_1999.rawValue)))
    private static let gb18030 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(
        CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
}
