import Foundation

/// Entry point for "import this file": picks the parser by type and returns
/// the `ImportedCollection` that `LibraryStore.applyDocImport` persists.
public enum LocalFileImporter {
    public enum FileType: Equatable, Sendable { case pdf, epub, text }

    public static func fileType(fileName: String, typeIdentifier: String?) -> FileType? {
        switch (fileName as NSString).pathExtension.lowercased() {
        case "pdf": return .pdf
        case "epub": return .epub
        case "txt", "text": return .text
        default: break
        }
        switch typeIdentifier {
        case "com.adobe.pdf": return .pdf
        case "org.idpf.epub-container": return .epub
        case "public.plain-text", "public.text", "public.utf8-plain-text", "public.utf16-plain-text": return .text
        default: return nil
        }
    }

    public static func importFile(data: Data, fileName: String, typeIdentifier: String?) throws -> ImportedCollection {
        guard let type = fileType(fileName: fileName, typeIdentifier: typeIdentifier) else {
            throw LocalFileImportError.unsupportedType
        }
        guard data.count <= LocalFileIdentity.maxFileSize else { throw LocalFileImportError.fileTooLarge }
        let imported: ImportedCollection
        switch type {
        case .pdf:
            #if canImport(PDFKit)
            imported = try PDFChapterExtractor.extract(data: data, fileName: fileName)
            #else
            throw LocalFileImportError.unsupportedType
            #endif
        case .epub:
            imported = try EPUBParser.parse(data: data, fileName: fileName)
        case .text:
            guard let text = TextEncodingDetector.decode(data) else { throw LocalFileImportError.undecodableText }
            imported = TextChapterSplitter.split(text: text, fileName: fileName)
        }
        guard !imported.chapters.isEmpty else { throw LocalFileImportError.noChapters }
        return imported
    }
}
