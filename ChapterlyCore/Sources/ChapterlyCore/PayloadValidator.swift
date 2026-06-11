import Foundation

public enum PayloadValidator {
    public static let forbiddenKeys: Set<String> = [
        "bodytext", "innertext", "innerhtml", "html", "content",
        "article", "paragraphs", "images", "comments"
    ]
    public static let maxFieldLength = 1024
    public static let maxURLLength = 2048
    public static let maxMessageBytes = 256 * 1024

    public static func validateImporterChapter(_ body: Any) -> Result<ImporterChapterPayload, PayloadError> {
        let required = ["title", "url", "collectionName", "collectionURL", "domOrder"]
        let optional = ["visibleDateText", "excerpt", "creatorName"]
        return checked(body, required: required, optional: optional).flatMap { dict in
            do {
                return .success(ImporterChapterPayload(
                    title: try string(dict, "title", max: maxFieldLength),
                    url: try string(dict, "url", max: maxURLLength),
                    visibleDateText: try optionalString(dict, "visibleDateText", max: maxFieldLength),
                    excerpt: try optionalString(dict, "excerpt", max: maxFieldLength),
                    creatorName: try optionalString(dict, "creatorName", max: maxFieldLength),
                    collectionName: try string(dict, "collectionName", max: maxFieldLength),
                    collectionURL: try string(dict, "collectionURL", max: maxURLLength),
                    domOrder: try int(dict, "domOrder")))
            } catch let e as PayloadError { return .failure(e) } catch { return .failure(.notADictionary) }
        }
    }

    public static func validateCollectionLink(_ body: Any) -> Result<CollectionLinkPayload, PayloadError> {
        return checked(body, required: ["collectionName", "collectionURL"], optional: []).flatMap { dict in
            do {
                return .success(CollectionLinkPayload(
                    collectionName: try string(dict, "collectionName", max: maxFieldLength),
                    collectionURL: try string(dict, "collectionURL", max: maxURLLength)))
            } catch let e as PayloadError { return .failure(e) } catch { return .failure(.notADictionary) }
        }
    }

    public static func validateProgress(_ body: Any) -> Result<ProgressPayload, PayloadError> {
        return checked(body, required: ["url", "scrollProgress"], optional: []).flatMap { dict in
            do {
                let url = try string(dict, "url", max: maxURLLength)
                guard let raw = dict["scrollProgress"] as? Double ?? (dict["scrollProgress"] as? Int).map(Double.init)
                else { return .failure(.wrongType("scrollProgress")) }
                return .success(ProgressPayload(url: url, scrollProgress: min(1.0, max(0.0, raw))))
            } catch let e as PayloadError { return .failure(e) } catch { return .failure(.notADictionary) }
        }
    }

    private static func checked(_ body: Any, required: [String], optional: [String])
        -> Result<[String: Any], PayloadError> {
        guard let dict = body as? [String: Any] else { return .failure(.notADictionary) }
        if let data = try? JSONSerialization.data(withJSONObject: dict), data.count > maxMessageBytes {
            return .failure(.tooLarge("message"))
        }
        let allowed = Set(required + optional)
        for key in dict.keys {
            if forbiddenKeys.contains(key.lowercased()) { return .failure(.forbiddenKey(key.lowercased())) }
        }
        for key in dict.keys where !allowed.contains(key) {
            return .failure(.unknownKey(key))
        }
        for key in required where dict[key] == nil || dict[key] is NSNull {
            return .failure(.missingKey(key))
        }
        return .success(dict)
    }

    private static func string(_ dict: [String: Any], _ key: String, max: Int) throws -> String {
        guard let value = dict[key] as? String else { throw PayloadError.wrongType(key) }
        guard value.utf8.count <= max else { throw PayloadError.tooLarge(key) }
        return value
    }

    private static func optionalString(_ dict: [String: Any], _ key: String, max: Int) throws -> String? {
        guard let raw = dict[key], !(raw is NSNull) else { return nil }
        return try string(dict, key, max: max)
    }

    private static func int(_ dict: [String: Any], _ key: String) throws -> Int {
        if let value = dict[key] as? NSNumber {
            guard CFGetTypeID(value) != CFBooleanGetTypeID() else {
                throw PayloadError.wrongType(key)
            }
            let doubleValue = value.doubleValue
            if doubleValue.isFinite,
               doubleValue.rounded(.towardZero) == doubleValue,
               doubleValue >= Double(Int.min),
               doubleValue <= Double(Int.max) {
                return value.intValue
            }
        }
        if let value = dict[key] as? Int {
            return value
        }
        if let value = dict[key] as? Double,
           value.isFinite,
           value.rounded(.towardZero) == value,
           value >= Double(Int.min),
           value <= Double(Int.max) {
            return Int(value)
        }
        throw PayloadError.wrongType(key)
    }
}
