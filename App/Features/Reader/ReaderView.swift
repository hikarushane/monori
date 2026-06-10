import SwiftUI
import ChapterlyCore

struct ReaderView: View {
    let chapter: LocalChapterModel
    var body: some View { Text(chapter.title) }
}
