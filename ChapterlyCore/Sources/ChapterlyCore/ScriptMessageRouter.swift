import Foundation

public final class ScriptMessageRouter {
    public static let importName = "chapterlyImport"
    public static let collectionLinkName = "chapterlyCollectionLink"
    public static let progressName = "chapterlyProgress"

    public static var allHandlerNames: [String] { [importName, collectionLinkName, progressName] }

    public var onImporterChapter: ((ImporterChapterPayload) -> Void)?
    public var onCollectionLink: ((CollectionLinkPayload) -> Void)?
    public var onProgress: ((ProgressPayload) -> Void)?

    public private(set) var rejectedCount = 0

    public init() {}

    public func route(name: String, body: Any) {
        switch name {
        case Self.importName:
            deliver(PayloadValidator.validateImporterChapter(body), to: onImporterChapter)
        case Self.collectionLinkName:
            deliver(PayloadValidator.validateCollectionLink(body), to: onCollectionLink)
        case Self.progressName:
            deliver(PayloadValidator.validateProgress(body), to: onProgress)
        default:
            rejectedCount += 1
        }
    }

    private func deliver<T>(_ result: Result<T, PayloadError>, to callback: ((T) -> Void)?) {
        switch result {
        case .success(let payload): callback?(payload)
        case .failure: rejectedCount += 1
        }
    }
}
