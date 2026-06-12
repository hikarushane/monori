import Foundation

public final class ScriptMessageRouter {
    public static let importName = "chapterlyImport"
    public static let collectionLinkName = "chapterlyCollectionLink"

    public static var allHandlerNames: [String] { [importName, collectionLinkName] }

    public var onImporterChapter: ((ImporterChapterPayload) -> Void)?
    public var onCollectionLink: ((CollectionLinkPayload) -> Void)?

    public private(set) var rejectedCount = 0
    public private(set) var lastRejectedReason: String?

    public init() {}

    public func route(name: String, body: Any) {
        switch name {
        case Self.importName:
            deliver(PayloadValidator.validateImporterChapter(body), to: onImporterChapter)
        case Self.collectionLinkName:
            deliver(PayloadValidator.validateCollectionLink(body), to: onCollectionLink)
        default:
            reject("unknown_handler")
        }
    }

    private func deliver<T>(_ result: Result<T, PayloadError>, to callback: ((T) -> Void)?) {
        switch result {
        case .success(let payload): callback?(payload)
        case .failure(let error): reject(Self.describe(error))
        }
    }

    private func reject(_ reason: String) {
        rejectedCount += 1
        lastRejectedReason = reason
    }

    private static func describe(_ error: PayloadError) -> String {
        switch error {
        case .notADictionary: return "not_a_dictionary"
        case .forbiddenKey(let key): return "forbiddenKey_\(key)"
        case .unknownKey(let key): return "unknownKey_\(key)"
        case .missingKey(let key): return "missingKey_\(key)"
        case .wrongType(let key): return "wrongType_\(key)"
        case .tooLarge(let key): return "tooLarge_\(key)"
        }
    }
}
