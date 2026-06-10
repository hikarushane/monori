import SwiftUI
import ChapterlyCore

struct ReaderView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var current: LocalChapterModel
    @State private var prefs = ReaderPreferences()

    init(chapter: LocalChapterModel) {
        _current = State(initialValue: chapter)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            PatreonWebView(model: env.reader)
            bottomBar
        }
        .onAppear { open(current) }
        .onChange(of: env.reader.currentURL) { _, _ in applyReaderTreatment() }
    }

    private var neighbors: (previous: LocalChapterModel?, next: LocalChapterModel?) {
        env.store.neighbors(of: current)
    }

    private func open(_ chapter: LocalChapterModel) {
        current = chapter
        if let url = URL(string: chapter.urlString) {
            env.reader.load(url)
        }
    }

    private func applyReaderTreatment() {
        guard env.reader.currentURL != nil else { return }
        let webView = env.reader.webView
        if prefs.readerModeEnabled {
            webView.evaluateJavaScript(ReaderStyler.injectionScript(), completionHandler: nil)
            webView.evaluateJavaScript(ReaderStyler.fontSizeScript(points: prefs.fontSize),
                                       completionHandler: nil)
        }
        if let progress = current.readingProgress, progress > 0.02, progress < 0.97 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                webView.evaluateJavaScript(
                    ReaderStyler.restoreScrollScript(progress: progress), completionHandler: nil)
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: { Image(systemName: "chevron.down") }
                .accessibilityLabel("Close reader")
            Spacer()
            Text(current.title).font(.subheadline.weight(.medium)).lineLimit(1)
            Spacer()
            Menu {
                Button("Increase font") { prefs.fontSize = min(32, prefs.fontSize + 1) }
                Button("Decrease font") { prefs.fontSize = max(14, prefs.fontSize - 1) }
                Toggle("Reader mode", isOn: $prefs.readerModeEnabled)
                if let url = URL(string: current.urlString) {
                    Link("Open on Patreon", destination: url)
                }
            } label: {
                Image(systemName: "textformat.size")
            }
            .accessibilityLabel("Reading options")
            .onChange(of: prefs.fontSize) { _, size in
                env.reader.webView.evaluateJavaScript(
                    ReaderStyler.fontSizeScript(points: size), completionHandler: nil)
            }
            .onChange(of: prefs.readerModeEnabled) { _, enabled in
                env.reader.webView.evaluateJavaScript(
                    enabled ? ReaderStyler.injectionScript() : ReaderStyler.removalScript(),
                    completionHandler: nil)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var bottomBar: some View {
        HStack {
            if let previous = neighbors.previous {
                Button { open(previous) } label: {
                    Label(previous.title, systemImage: "chevron.left")
                        .lineLimit(1)
                }
            }
            Spacer()
            if let next = neighbors.next {
                Button { open(next) } label: {
                    HStack {
                        Text(next.title).lineLimit(1)
                        Image(systemName: "chevron.right")
                    }
                }
            }
        }
        .font(.subheadline)
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }
}
