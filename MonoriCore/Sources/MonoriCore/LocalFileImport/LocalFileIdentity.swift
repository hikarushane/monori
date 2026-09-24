import Foundation

/// Identity rules for collections imported from the user's own files.
/// The file name is the identity: re-importing a file with the same name
/// merges into the existing collection through `LibraryStore.applyDocImport`.
public enum LocalFileIdentity {
    public static let scheme = "monori-local"
    public static let maxFileSize = 50 * 1024 * 1024

    public static func sourceURLString(fileName: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let encoded = fileName.addingPercentEncoding(withAllowedCharacters: allowed) ?? fileName
        return "\(scheme)://file/\(encoded)"
    }

    public static func chapterURLString(sourceURLString: String, orderIndex: Int) -> String {
        "\(sourceURLString)#\(orderIndex)"
    }

    public static func title(fromFileName fileName: String) -> String {
        let name = (fileName as NSString).deletingPathExtension
        return name.isEmpty ? fileName : name
    }
}

public enum LocalFileImportError: Error, Equatable, Sendable {
    case unsupportedType
    case fileTooLarge
    case unreadableFile
    case undecodableText
    case notAnEPUB
    case drmProtected
    case epubWithoutSpine
    case unreadablePDF
    case encryptedPDF
    case pdfWithoutText
    case noChapters

    /// User-facing message shown in the import failure alert.
    public var message: String {
        switch self {
        case .unsupportedType: return "不支援的檔案類型。請選擇 PDF、EPUB 或 TXT。"
        case .fileTooLarge: return "檔案超過 50 MB，無法匯入。"
        case .unreadableFile: return "無法讀取這個檔案。"
        case .undecodableText: return "無法辨識文字編碼。請將檔案另存為 UTF-8 後再試。"
        case .notAnEPUB: return "不是有效的 EPUB。"
        case .drmProtected: return "這個 EPUB 有 DRM 保護，無法匯入。"
        case .epubWithoutSpine: return "這個 EPUB 沒有可讀取的章節。"
        case .unreadablePDF: return "無法讀取這個 PDF。"
        case .encryptedPDF: return "PDF 已加密，無法匯入。"
        case .pdfWithoutText: return "這個 PDF 沒有可讀取的文字。"
        case .noChapters: return "檔案裡找不到任何內容。"
        }
    }
}
