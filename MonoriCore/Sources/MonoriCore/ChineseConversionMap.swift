import Foundation

public final class ChineseConversionMap: @unchecked Sendable {
    public static let shared = ChineseConversionMap()

    private var _s2t: String?
    private var _t2s: String?
    private let lock = NSLock()

    public var s2tMap: String {
        lock.lock()
        defer { lock.unlock() }
        if let cached = _s2t { return cached }
        let result = Self.buildMap(transform: "Hans-Hant")
        _s2t = result
        return result
    }

    public var t2sMap: String {
        lock.lock()
        defer { lock.unlock() }
        if let cached = _t2s { return cached }
        let result = Self.buildMap(transform: "Hant-Hans")
        _t2s = result
        return result
    }

    private static func buildMap(transform: String) -> String {
        var pairs = ""
        pairs.reserveCapacity(6000)
        for codePoint in 0x4E00...0x9FFF {
            guard let scalar = Unicode.Scalar(codePoint) else { continue }
            let original = String(scalar)
            let mutable = NSMutableString(string: original)
            CFStringTransform(mutable, nil, transform as CFString, false)
            let converted = mutable as String
            // The reader script indexes the map by UTF-16 unit, so a
            // supplementary-plane result (ICU emits ~160 for Hant-Hans)
            // must be dropped or every later pair shifts by one.
            if converted != original && converted.utf16.count == 1 {
                pairs.append(original)
                pairs.append(converted)
            }
        }
        return pairs
    }
}
