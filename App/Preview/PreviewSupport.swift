#if DEBUG
import SwiftUI
import SwiftData
import MonoriCore

@MainActor
enum PreviewSupport {

    static func emptyEnvironment() -> AppEnvironment {
        let env = AppEnvironment(store: try! LibraryStore.inMemory())
        env.appPrefs.autoCheckEnabled = false
        return env
    }

    static func sampleLibraryEnvironment() -> AppEnvironment {
        let store = try! LibraryStore.inMemory()
        let env = AppEnvironment(store: store)
        env.appPrefs.autoCheckEnabled = false
        seedSampleCollections(into: store)
        return env
    }

    static func unreadLibraryEnvironment() -> AppEnvironment {
        let store = try! LibraryStore.inMemory()
        let env = AppEnvironment(store: store)
        env.appPrefs.autoCheckEnabled = false
        seedUnreadCollections(into: store)
        return env
    }

    static func sampleCollection(
        source: SourceKind = .patreon,
        chapterCount: Int = 8
    ) -> (env: AppEnvironment, collection: LocalCollectionModel) {
        let store = try! LibraryStore.inMemory()
        let env = AppEnvironment(store: store)
        env.appPrefs.autoCheckEnabled = false
        let collection = makeSingleCollection(
            into: store, source: source, chapterCount: chapterCount)
        return (env, collection)
    }

    // MARK: - Seed

    private static func seedSampleCollections(into store: LibraryStore) {
        let ctx = store.container.mainContext

        let c1 = LocalCollectionModel(
            title: "星辰與深淵的交界處：一部關於時間旅行者的漫長敘事",
            sourceURLString: "https://www.patreon.com/collection/1",
            creatorName: "筆名極長的創作者 LongPenName",
            sourceKind: .patreon)
        ctx.insert(c1)
        for i in 0..<12 {
            let ch = LocalChapterModel(
                title: "第 \(i + 1) 章",
                urlString: "https://www.patreon.com/posts/\(1000 + i)",
                orderIndex: i)
            ch.collection = c1
            ctx.insert(ch)
        }

        let c2 = LocalCollectionModel(
            title: "before sunrise",
            sourceURLString: "https://archiveofourown.org/works/12345",
            creatorName: "ao3writer",
            sourceKind: .ao3)
        ctx.insert(c2)
        let ao3Titles = ["Dawn", "Morning", "Noon", "Dusk", "Night"]
        for i in 0..<5 {
            let ch = LocalChapterModel(
                title: "Chapter \(i + 1): \(ao3Titles[i])",
                urlString: "https://archiveofourown.org/works/12345/chapters/\(200 + i)",
                orderIndex: i)
            ch.collection = c2
            ctx.insert(ch)
        }

        let c3 = LocalCollectionModel(
            title: "都市觀察筆記",
            sourceURLString: "https://vocus.cc/user/room/abc",
            creatorName: "散步的貓",
            sourceKind: .vocus)
        ctx.insert(c3)
        let vocusTitles = ["咖啡店裡的陌生人", "雨天的電車", "巷口的麵攤"]
        for i in 0..<3 {
            let ch = LocalChapterModel(
                title: vocusTitles[i],
                urlString: "https://vocus.cc/article/\(300 + i)",
                orderIndex: i)
            ch.collection = c3
            ctx.insert(ch)
        }

        let c4 = LocalCollectionModel(
            title: "讀書會討論稿",
            sourceURLString: "https://docs.google.com/document/d/abc123",
            sourceKind: .googleDocs)
        ctx.insert(c4)
        let ch4 = LocalChapterModel(
            title: "全文",
            urlString: "https://docs.google.com/document/d/abc123",
            orderIndex: 0)
        ch4.contentHTML = "<p>Preview fixture content</p>"
        ch4.collection = c4
        ctx.insert(ch4)

        let c5 = LocalCollectionModel(
            title: "Heartbeat",
            sourceURLString: "https://www.asianfanfics.com/story/view/999",
            creatorName: "kpopfanwriter",
            sourceKind: .asianFanfics)
        ctx.insert(c5)
        for i in 0..<7 {
            let ch = LocalChapterModel(
                title: "Part \(i + 1)",
                urlString: "https://www.asianfanfics.com/story/view/999/\(i + 1)",
                orderIndex: i)
            ch.collection = c5
            ctx.insert(ch)
        }

        let c6 = LocalCollectionModel(
            title: "完結作品",
            sourceURLString: "https://archiveofourown.org/works/67890",
            creatorName: "finishedauthor",
            sourceKind: .ao3)
        c6.readingStatus = .finished
        ctx.insert(c6)
        for i in 0..<20 {
            let ch = LocalChapterModel(
                title: "Chapter \(i + 1)",
                urlString: "https://archiveofourown.org/works/67890/chapters/\(400 + i)",
                orderIndex: i)
            ch.collection = c6
            ctx.insert(ch)
        }

        try? ctx.save()
    }

    private static func seedUnreadCollections(into store: LibraryStore) {
        let ctx = store.container.mainContext

        let c1 = LocalCollectionModel(
            title: "持續更新的系列",
            sourceURLString: "https://www.patreon.com/collection/unread1",
            creatorName: "勤勞的作者",
            sourceKind: .patreon)
        c1.lastNewChapterAt = Date()
        ctx.insert(c1)
        for i in 0..<5 {
            let ch = LocalChapterModel(
                title: "第 \(i + 1) 章",
                urlString: "https://www.patreon.com/posts/\(2000 + i)",
                orderIndex: i)
            ch.isNew = i >= 3
            ch.collection = c1
            ctx.insert(ch)
        }

        let c2 = LocalCollectionModel(
            title: "another updating work",
            sourceURLString: "https://archiveofourown.org/works/55555",
            creatorName: "busywriter",
            sourceKind: .ao3)
        c2.lastNewChapterAt = Date().addingTimeInterval(-3600)
        ctx.insert(c2)
        for i in 0..<8 {
            let ch = LocalChapterModel(
                title: "Chapter \(i + 1)",
                urlString: "https://archiveofourown.org/works/55555/chapters/\(600 + i)",
                orderIndex: i)
            ch.isNew = i >= 5
            ch.collection = c2
            ctx.insert(ch)
        }

        let c3 = LocalCollectionModel(
            title: "已讀完的收藏",
            sourceURLString: "https://vocus.cc/user/room/read",
            creatorName: "某作者",
            sourceKind: .vocus)
        ctx.insert(c3)
        for i in 0..<4 {
            let ch = LocalChapterModel(
                title: "篇 \(i + 1)",
                urlString: "https://vocus.cc/article/\(700 + i)",
                orderIndex: i)
            ch.collection = c3
            ctx.insert(ch)
        }

        try? ctx.save()
    }

    private static func makeSingleCollection(
        into store: LibraryStore,
        source: SourceKind,
        chapterCount: Int
    ) -> LocalCollectionModel {
        let ctx = store.container.mainContext

        let titles: [SourceKind: String] = [
            .patreon: "Patreon 系列作品",
            .ao3: "AO3 Long Fic Title That Might Wrap to Two Lines",
            .vocus: "方格子專題",
            .googleDocs: "Google 文件",
            .asianFanfics: "AFF Story",
        ]
        let creators: [SourceKind: String?] = [
            .patreon: "creator_name",
            .ao3: "ao3author",
            .vocus: "方格子作者",
            .googleDocs: nil,
            .asianFanfics: "affwriter",
        ]

        let collection = LocalCollectionModel(
            title: titles[source] ?? "Collection",
            sourceURLString: "https://example.com/\(source.rawValue)/preview",
            creatorName: creators[source] ?? nil,
            sourceKind: source)
        ctx.insert(collection)

        for i in 0..<chapterCount {
            let ch = LocalChapterModel(
                title: "Chapter \(i + 1)",
                urlString: "https://example.com/\(source.rawValue)/ch/\(i)",
                orderIndex: i)
            if i == 2 { ch.isBookmarked = true }
            if i >= chapterCount - 2 { ch.isNew = true }
            ch.collection = collection
            ctx.insert(ch)
        }

        try? ctx.save()
        return collection
    }

    // MARK: - Stress

    static func stressEnvironment() -> AppEnvironment {
        let store = try! LibraryStore.inMemory()
        let env = AppEnvironment(store: store)
        env.appPrefs.autoCheckEnabled = false
        seedStressCollections(into: store)
        return env
    }

    static func stressCollection() -> (env: AppEnvironment, collection: LocalCollectionModel) {
        let store = try! LibraryStore.inMemory()
        let env = AppEnvironment(store: store)
        env.appPrefs.autoCheckEnabled = false
        let collection = makeLargeCollection(into: store)
        return (env, collection)
    }

    private static func seedStressCollections(into store: LibraryStore) {
        let ctx = store.container.mainContext

        let c1 = LocalCollectionModel(
            title: "這是一個極端長的書名用來測試書庫列表在 Dynamic Type 最大級別下會不會截斷重疊或爆版🌸✨ — A Very Long Title Mixed with English & 日本語タイトル",
            sourceURLString: "https://www.patreon.com/collection/stress1",
            creatorName: "筆名也可以非常非常長的創作者 SuperLongPenName 超長ペンネーム 🖊️✍️",
            sourceKind: .patreon)
        c1.lastNewChapterAt = Date()
        ctx.insert(c1)
        for i in 0..<50 {
            let ch = LocalChapterModel(
                title: "第 \(i + 1) 章：這個章節標題也很長，包含中日英混排 Chapter Title ちょっと長いタイトル 🎭",
                urlString: "https://www.patreon.com/posts/\(5000 + i)",
                orderIndex: i)
            ch.isNew = i >= 40
            ch.collection = c1
            ctx.insert(ch)
        }

        let c2 = LocalCollectionModel(
            title: "nil metadata collection",
            sourceURLString: "https://archiveofourown.org/works/stress2",
            sourceKind: .ao3)
        ctx.insert(c2)
        let ch2 = LocalChapterModel(
            title: "Solo chapter",
            urlString: "https://archiveofourown.org/works/stress2/chapters/1",
            orderIndex: 0)
        ch2.collection = c2
        ctx.insert(ch2)

        let c3 = LocalCollectionModel(
            title: "😈🔥 emoji-heavy title 💕✨🌙 星月夜に咲く花 🌸",
            sourceURLString: "https://vocus.cc/user/room/stress3",
            creatorName: "🐱猫作者🐱",
            sourceKind: .vocus)
        c3.readingStatus = .dropped
        ctx.insert(c3)
        for i in 0..<3 {
            let ch = LocalChapterModel(
                title: "篇 \(i + 1) 🌟",
                urlString: "https://vocus.cc/article/stress\(i)",
                orderIndex: i)
            ch.collection = c3
            ctx.insert(ch)
        }

        try? ctx.save()
    }

    private static func makeLargeCollection(into store: LibraryStore) -> LocalCollectionModel {
        let ctx = store.container.mainContext

        let collection = LocalCollectionModel(
            title: "Stress Test: 極端長的收藏標題用來驗證目錄頁面排版 — 中英日 CJK Mixed タイトル 🔥✨",
            sourceURLString: "https://example.com/stress/toc",
            creatorName: "非常長的作者名 A Very Long Author Name 超長い著者名 🖊️",
            sourceKind: .patreon)
        collection.lastNewChapterAt = Date()
        ctx.insert(collection)

        for i in 0..<60 {
            let ch = LocalChapterModel(
                title: i % 5 == 0
                    ? "第 \(i + 1) 章：中日英混排標題 Chapter Title That Is Unreasonably Long タイトル 🎭🌸"
                    : "Chapter \(i + 1)",
                urlString: "https://example.com/stress/ch/\(i)",
                orderIndex: i)
            if i == 10 { ch.isBookmarked = true }
            ch.isNew = i >= 50
            ch.collection = collection
            ctx.insert(ch)
        }

        try? ctx.save()
        return collection
    }
}
#endif
