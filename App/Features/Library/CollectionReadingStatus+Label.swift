import MonoriCore

extension CollectionReadingStatus {
    var label: String {
        switch self {
        case .reading: "追更"
        case .finished: "完食"
        case .dropped: "棄坑"
        }
    }
}
