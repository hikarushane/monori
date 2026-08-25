import MonoriCore

extension CollectionReadingStatus {
    var label: String {
        switch self {
        case .reading: "追更中"
        case .finished: "已讀完"
        case .dropped: "棄坑"
        }
    }
}
