#if canImport(PDFKit)
import Foundation
import PDFKit

/// Extracts a PDF's text into chapters. With an outline, each top-level
/// (flattened) entry starts a chapter at its destination page; without one,
/// the full text goes through `TextChapterSplitter` so 「第X章」 headings still
/// produce a table of contents. Layout and images are not preserved.
public enum PDFChapterExtractor {
    public static func extract(data: Data, fileName: String) throws -> ImportedCollection {
        guard data.count <= LocalFileIdentity.maxFileSize else { throw LocalFileImportError.fileTooLarge }
        guard let document = PDFDocument(data: data) else { throw LocalFileImportError.unreadablePDF }
        return try extract(document: document, fileName: fileName)
    }

    public static func extract(document: PDFDocument, fileName: String) throws -> ImportedCollection {
        if document.isEncrypted && document.isLocked { throw LocalFileImportError.encryptedPDF }
        let pageCount = document.pageCount
        let pageTexts: [String] = (0..<pageCount).map { document.page(at: $0)?.string ?? "" }
        guard pageTexts.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw LocalFileImportError.pdfWithoutText
        }

        let sourceURL = LocalFileIdentity.sourceURLString(fileName: fileName)
        let attributes = document.documentAttributes ?? [:]
        let attrTitle = (attributes[PDFDocumentAttribute.titleAttribute] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let attrAuthor = (attributes[PDFDocumentAttribute.authorAttribute] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let title = (attrTitle?.isEmpty == false ? attrTitle : nil) ?? LocalFileIdentity.title(fromFileName: fileName)
        let creator = attrAuthor?.isEmpty == false ? attrAuthor : nil

        let starts = outlineStarts(document)
        let chapters: [ImportedChapter]
        if starts.isEmpty {
            let split = TextChapterSplitter.split(text: pageTexts.joined(separator: "\n\n"), fileName: fileName)
            chapters = split.chapters
        } else {
            var bodies: [(title: String, html: String)] = []
            let foreword = PlainTextHTML.render(text: pageTexts[0..<starts[0].page].joined(separator: "\n\n"))
            if !foreword.isEmpty { bodies.append((TextChapterSplitter.forewordTitle, foreword)) }
            for (n, start) in starts.enumerated() {
                let end = n + 1 < starts.count ? starts[n + 1].page : pageCount
                let html = PlainTextHTML.render(text: pageTexts[start.page..<end].joined(separator: "\n\n"))
                if !html.isEmpty { bodies.append((start.label, html)) }
            }
            chapters = bodies.enumerated().map { index, body in
                ImportedChapter(title: body.title,
                                urlString: LocalFileIdentity.chapterURLString(sourceURLString: sourceURL, orderIndex: index),
                                orderIndex: index,
                                contentHTML: body.html)
            }
        }
        guard !chapters.isEmpty else { throw LocalFileImportError.noChapters }
        return ImportedCollection(sourceURLString: sourceURL, title: title, creatorName: creator,
                                  sourceKind: .localFile, chapters: chapters)
    }

    /// Outline entries with a page destination, depth-first, sorted by page,
    /// one entry per page (the first wins).
    static func outlineStarts(_ document: PDFDocument) -> [(label: String, page: Int)] {
        guard let root = document.outlineRoot else { return [] }
        var found: [(String, Int)] = []
        func walk(_ node: PDFOutline) {
            for i in 0..<node.numberOfChildren {
                guard let child = node.child(at: i) else { continue }
                if let page = child.destination?.page {
                    let index = document.index(for: page)
                    let label = child.label?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    found.append((label.isEmpty ? "第 \(found.count + 1) 章" : label, index))
                }
                walk(child)
            }
        }
        walk(root)
        var seen = Set<Int>()
        return found.sorted { $0.1 < $1.1 }.filter { seen.insert($0.1).inserted }
    }
}
#endif
