import Foundation

public struct ImporterChapterPayload: Equatable {
    public let title: String
    public let url: String
    public let visibleDateText: String?
    public let collectionName: String
    public let collectionURL: String
    public let domOrder: Int

    public init(title: String, url: String, visibleDateText: String?,
                collectionName: String, collectionURL: String, domOrder: Int) {
        self.title = title
        self.url = url
        self.visibleDateText = visibleDateText
        self.collectionName = collectionName
        self.collectionURL = collectionURL
        self.domOrder = domOrder
    }
}

public struct CollectionLinkPayload: Equatable {
    public let collectionName: String
    public let collectionURL: String

    public init(collectionName: String, collectionURL: String) {
        self.collectionName = collectionName
        self.collectionURL = collectionURL
    }
}

public struct ProgressPayload: Equatable {
    public let url: String
    public let scrollProgress: Double

    public init(url: String, scrollProgress: Double) {
        self.url = url
        self.scrollProgress = scrollProgress
    }
}

public enum PayloadError: Error, Equatable {
    case notADictionary
    case forbiddenKey(String)   // lowercased key name
    case unknownKey(String)
    case missingKey(String)
    case wrongType(String)
    case tooLarge(String)
}
