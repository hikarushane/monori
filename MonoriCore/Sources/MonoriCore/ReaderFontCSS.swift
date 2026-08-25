import Foundation

public enum ReaderFontCSS: Equatable, Sendable {
    case builtIn
    case embeddedDataURL(mimeType: String, base64: String)
}
