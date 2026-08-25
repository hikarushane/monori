import Foundation
import CoreGraphics
import CoreText
import MonoriCore
import CryptoKit

@MainActor
final class ReaderFontStore {
    static let maxFileSize = 25 * 1024 * 1024

    private let baseDirectory: URL
    private let manifestURL: URL
    private(set) var fonts: [ReaderFontDescriptor] = []

    init(directory: URL? = nil) {
        let dir = directory ?? Self.defaultDirectory()
        self.baseDirectory = dir
        self.manifestURL = dir.appendingPathComponent("manifest.json")
        ensureDirectory()
        loadManifest()
    }

    private static func defaultDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory,
                                                   in: .userDomainMask).first!
        return appSupport.appendingPathComponent("ReaderFonts", isDirectory: true)
    }

    private func ensureDirectory() {
        try? FileManager.default.createDirectory(at: baseDirectory,
                                                  withIntermediateDirectories: true)
    }

    // MARK: - Manifest

    private func loadManifest() {
        guard let data = try? Data(contentsOf: manifestURL),
              let decoded = try? JSONDecoder().decode([ReaderFontDescriptor].self, from: data) else {
            fonts = []
            return
        }
        fonts = decoded.filter { descriptor in
            guard let fileName = descriptor.storedFileName else { return false }
            return FileManager.default.fileExists(atPath:
                baseDirectory.appendingPathComponent(fileName).path)
        }
        if fonts.count != decoded.count {
            saveManifest()
        }
    }

    private func saveManifest() {
        guard let data = try? JSONEncoder().encode(fonts) else { return }
        try? data.write(to: manifestURL, options: .atomic)
    }

    // MARK: - Import

    enum ImportError: Error, Equatable {
        case fileTooBig
        case invalidFont
        case alreadyImported(String)
        case copyFailed
    }

    func importFont(from sourceURL: URL) throws -> ReaderFontDescriptor {
        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer { if accessing { sourceURL.stopAccessingSecurityScopedResource() } }

        let attributes = try FileManager.default.attributesOfItem(atPath: sourceURL.path)
        let fileSize = (attributes[.size] as? Int) ?? 0
        guard fileSize <= Self.maxFileSize else { throw ImportError.fileTooBig }

        let data = try Data(contentsOf: sourceURL)
        let hash = SHA256.hash(data: data)
        let hashString = hash.map { String(format: "%02x", $0) }.joined()

        if let existing = fonts.first(where: { $0.id == hashString }) {
            throw ImportError.alreadyImported(existing.displayName)
        }

        guard let (displayName, _) = validateFont(data: data) else {
            throw ImportError.invalidFont
        }

        let ext = sourceURL.pathExtension.lowercased()
        let safeExt = (ext == "otf") ? "otf" : "ttf"
        let storedName = "\(hashString).\(safeExt)"
        let destURL = baseDirectory.appendingPathComponent(storedName)

        let tmpURL = baseDirectory.appendingPathComponent(".\(storedName).tmp")
        do {
            try data.write(to: tmpURL, options: .atomic)
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.moveItem(at: tmpURL, to: destURL)
        } catch {
            try? FileManager.default.removeItem(at: tmpURL)
            throw ImportError.copyFailed
        }

        let descriptor = ReaderFontDescriptor(
            id: hashString,
            kind: .imported,
            displayName: displayName,
            storedFileName: storedName)
        fonts.append(descriptor)
        saveManifest()
        return descriptor
    }

    // MARK: - Validation

    private func validateFont(data: Data) -> (displayName: String, postScriptName: String?)? {
        guard let provider = CGDataProvider(data: data as CFData),
              let cgFont = CGFont(provider) else { return nil }
        let postScript = cgFont.postScriptName as String?
        let fullName = cgFont.fullName as String?
        let display = fullName ?? postScript ?? "Unknown Font"
        return (display, postScript)
    }

    // MARK: - Delete

    func deleteFont(id: String) {
        guard let index = fonts.firstIndex(where: { $0.id == id }) else { return }
        let descriptor = fonts[index]
        if let fileName = descriptor.storedFileName {
            let fileURL = baseDirectory.appendingPathComponent(fileName)
            try? FileManager.default.removeItem(at: fileURL)
        }
        fonts.remove(at: index)
        saveManifest()
    }

    // MARK: - Resolve

    func descriptor(for id: String) -> ReaderFontDescriptor? {
        if id == ReaderFontDescriptor.builtInDefault.id { return .builtInDefault }
        return fonts.first(where: { $0.id == id })
    }

    func fontData(for descriptor: ReaderFontDescriptor) -> Data? {
        guard let fileName = descriptor.storedFileName else { return nil }
        let url = baseDirectory.appendingPathComponent(fileName)
        return try? Data(contentsOf: url)
    }

    func resolveCSS(for id: String) -> ReaderFontCSS {
        guard id != ReaderFontDescriptor.builtInDefault.id,
              let descriptor = fonts.first(where: { $0.id == id }),
              let data = fontData(for: descriptor) else {
            return .builtIn
        }
        let ext = descriptor.storedFileName?.split(separator: ".").last.map(String.init) ?? "ttf"
        let mime = ext == "otf" ? "font/otf" : "font/ttf"
        return .embeddedDataURL(mimeType: mime, base64: data.base64EncodedString())
    }
}
