import Foundation
import ZIPFoundation

/// Parses a DRM-free EPUB 2/3 into an `ImportedCollection`. Pure: bytes in,
/// chapters out. Images and other media are dropped; the reader renders
/// text only. See docs/superpowers/specs/2026-09-24-local-file-source-design.md.
public enum EPUBParser {
    struct ManifestItem { let id: String; let href: String; let mediaType: String; let properties: String }
    struct SpineRef { let idref: String; let linear: Bool }
    struct Package {
        var title: String?
        var creator: String?
        var manifest: [String: ManifestItem] = [:]
        var spine: [SpineRef] = []
        var ncxID: String?
    }
    struct TOCEntry { let title: String; let href: String }   // href resolved to an archive path, fragment stripped

    public static func parse(data: Data, fileName: String) throws -> ImportedCollection {
        guard data.count <= LocalFileIdentity.maxFileSize else { throw LocalFileImportError.fileTooLarge }
        guard let archive = try? Archive(data: data, accessMode: .read) else { throw LocalFileImportError.notAnEPUB }
        let reader = ArchiveReader(archive: archive)

        guard let container = reader.string(at: "META-INF/container.xml"),
              let opfPath = ContainerParser.rootfilePath(in: container) else { throw LocalFileImportError.notAnEPUB }
        if reader.exists("META-INF/encryption.xml") { throw LocalFileImportError.drmProtected }
        guard let opfXML = reader.string(at: opfPath) else { throw LocalFileImportError.epubWithoutSpine }
        let package = OPFParser.parse(opfXML)
        let opfDir = ArchivePath.directory(of: opfPath)

        // Ordered readable spine: linear items that are XHTML and not the nav doc.
        let navItem = package.manifest.values.first { $0.properties.split(separator: " ").contains("nav") }
        let spineItems: [ManifestItem] = package.spine.compactMap { ref in
            guard ref.linear, let item = package.manifest[ref.idref] else { return nil }
            if let nav = navItem, nav.id == item.id { return nil }
            return item
        }
        guard !spineItems.isEmpty else { throw LocalFileImportError.epubWithoutSpine }
        let spinePaths = spineItems.map { ArchivePath.resolve($0.href, relativeTo: opfDir) }

        let toc = tocEntries(package: package, navItem: navItem, opfDir: opfDir, reader: reader)
        var bodies: [(title: String, html: String)] = []
        if let toc, !toc.isEmpty {
            bodies = chaptersFromTOC(toc, spinePaths: spinePaths, reader: reader)
        }
        if bodies.isEmpty {
            bodies = chaptersFromSpine(spinePaths, reader: reader)
        }
        guard !bodies.isEmpty else { throw LocalFileImportError.noChapters }

        let sourceURL = LocalFileIdentity.sourceURLString(fileName: fileName)
        let chapters = bodies.enumerated().map { index, body in
            ImportedChapter(title: body.title,
                            urlString: LocalFileIdentity.chapterURLString(sourceURLString: sourceURL, orderIndex: index),
                            orderIndex: index,
                            contentHTML: body.html)
        }
        let title = package.title.flatMap { $0.isEmpty ? nil : $0 } ?? LocalFileIdentity.title(fromFileName: fileName)
        let creator = package.creator.flatMap { $0.isEmpty ? nil : $0 }
        return ImportedCollection(sourceURLString: sourceURL, title: title, creatorName: creator,
                                  sourceKind: .localFile, chapters: chapters)
    }

    // MARK: Chapter assembly

    static func chaptersFromSpine(_ paths: [String], reader: ArchiveReader) -> [(title: String, html: String)] {
        var out: [(String, String)] = []
        for (i, path) in paths.enumerated() {
            guard let xhtml = reader.string(at: path) else { continue }
            let html = chapterHTML(from: xhtml)
            guard hasText(html) else { continue }
            out.append((chapterTitle(of: xhtml) ?? "第 \(i + 1) 章", html))
        }
        return out
    }

    /// Filled in by Task 6. Returns nil when the package declares no TOC.
    static func tocEntries(package: Package, navItem: ManifestItem?, opfDir: String,
                           reader: ArchiveReader) -> [TOCEntry]? {
        nil
    }

    /// Filled in by Task 6.
    static func chaptersFromTOC(_ toc: [TOCEntry], spinePaths: [String],
                                reader: ArchiveReader) -> [(title: String, html: String)] {
        []
    }

    // MARK: HTML helpers

    static func chapterHTML(from xhtml: String) -> String {
        if let body = bodyHTML(of: xhtml) {
            return stripMedia(HTMLSanitizer.sanitize(body))
        }
        return PlainTextHTML.render(text: stripTags(xhtml))
    }

    static func bodyHTML(of xhtml: String) -> String? {
        guard let m = firstMatch("<body[^>]*>([\\s\\S]*?)</body>", in: xhtml) else { return nil }
        return m
    }

    static func chapterTitle(of xhtml: String) -> String? {
        if let t = firstMatch("<title[^>]*>([\\s\\S]*?)</title>", in: xhtml) {
            let cleaned = collapse(stripTags(t))
            if !cleaned.isEmpty { return cleaned }
        }
        if let h = firstMatch("<h[1-3][^>]*>([\\s\\S]*?)</h[1-3]>", in: xhtml) {
            let cleaned = collapse(stripTags(h))
            if !cleaned.isEmpty { return cleaned }
        }
        return nil
    }

    static func stripMedia(_ html: String) -> String {
        var s = html
        for tag in ["svg", "picture", "video", "audio"] {
            s = s.replacingOccurrences(of: "<\(tag)\\b[^>]*>[\\s\\S]*?</\(tag)>", with: "",
                                      options: [.regularExpression, .caseInsensitive])
        }
        s = s.replacingOccurrences(of: "<(?:img|link)\\b[^>]*/?>", with: "",
                                  options: [.regularExpression, .caseInsensitive])
        // External links: keep the text, drop the anchor.
        s = s.replacingOccurrences(of: "<a\\b[^>]*href=\"(?:https?:|mailto:)[^\"]*\"[^>]*>([\\s\\S]*?)</a>",
                                  with: "$1", options: [.regularExpression, .caseInsensitive])
        return s
    }

    static func hasText(_ html: String) -> Bool {
        !stripTags(html).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func stripTags(_ html: String) -> String {
        html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }

    static func collapse(_ s: String) -> String {
        s.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let m = re.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              m.numberOfRanges > 1, let r = Range(m.range(at: 1), in: text) else { return nil }
        return String(text[r])
    }
}

// MARK: - Archive access

struct ArchiveReader {
    let archive: Archive

    func exists(_ path: String) -> Bool { archive[path] != nil }

    func data(at path: String) -> Data? {
        guard let entry = archive[path] else { return nil }
        var out = Data()
        do {
            _ = try archive.extract(entry, consumer: { out.append($0) })
        } catch { return nil }
        return out
    }

    func string(at path: String) -> String? {
        guard let d = data(at: path) else { return nil }
        return String(data: d, encoding: .utf8) ?? String(data: d, encoding: .utf16)
    }
}

enum ArchivePath {
    static func directory(of path: String) -> String {
        guard let slash = path.lastIndex(of: "/") else { return "" }
        return String(path[..<slash])
    }

    /// Resolves an href relative to a directory inside the archive, removing
    /// the fragment, percent-decoding, and collapsing `.` / `..` segments.
    static func resolve(_ href: String, relativeTo dir: String) -> String {
        let noFragment = href.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? href
        let decoded = noFragment.removingPercentEncoding ?? noFragment
        let joined = decoded.hasPrefix("/") ? String(decoded.dropFirst())
            : (dir.isEmpty ? decoded : dir + "/" + decoded)
        var parts: [String] = []
        for seg in joined.split(separator: "/", omittingEmptySubsequences: true) {
            if seg == "." { continue }
            if seg == ".." { _ = parts.popLast(); continue }
            parts.append(String(seg))
        }
        return parts.joined(separator: "/")
    }
}

// MARK: - XML parsers

enum ContainerParser {
    static func rootfilePath(in xml: String) -> String? {
        EPUBParser.firstMatch("<rootfile[^>]*full-path=\"([^\"]+)\"", in: xml)
    }
}

final class OPFParser: NSObject, XMLParserDelegate {
    private var package = EPUBParser.Package()
    private var text = ""
    private var capturing: String?

    static func parse(_ xml: String) -> EPUBParser.Package {
        let p = OPFParser()
        let parser = XMLParser(data: Data(xml.utf8))
        parser.delegate = p
        parser.shouldProcessNamespaces = true
        parser.parse()
        return p.package
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String]) {
        switch elementName {
        case "title" where package.title == nil, "creator" where package.creator == nil:
            capturing = elementName; text = ""
        case "item":
            guard let id = attributes["id"], let href = attributes["href"] else { return }
            package.manifest[id] = .init(id: id, href: href,
                                         mediaType: attributes["media-type"] ?? "",
                                         properties: attributes["properties"] ?? "")
        case "spine":
            package.ncxID = attributes["toc"]
        case "itemref":
            guard let idref = attributes["idref"] else { return }
            package.spine.append(.init(idref: idref, linear: attributes["linear"]?.lowercased() != "no"))
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if capturing != nil { text += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        guard let c = capturing, c == elementName else { return }
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if c == "title" { package.title = value } else { package.creator = value }
        capturing = nil
    }
}
