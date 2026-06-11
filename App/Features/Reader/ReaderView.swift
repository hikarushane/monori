import SwiftUI
import WebKit
import ChapterlyCore

struct ReaderView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var current: LocalChapterModel
    @State private var prefs = ReaderPreferences()
    @State private var targetProgress: Double?
    /// Non-nil while the web view shows a page outside the library (e.g. a related
    /// post from a collection that has not been imported). Holds the display title.
    @State private var foreignPageTitle: String?
    @State private var foreignTitleTask: Task<Void, Never>?

    init(chapter: LocalChapterModel) {
        _current = State(initialValue: chapter)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            PatreonWebView(model: env.reader)
                .accessibilityIdentifier("smoke.readerWebView")
            bottomBar
        }
        .onAppear { open(current) }
        .onDisappear { foreignTitleTask?.cancel() }
        .onChange(of: env.reader.finishedNavigationCount) { _, _ in applyReaderTreatment() }
        .onChange(of: env.reader.currentURL) { _, newURL in syncCurrentChapter(to: newURL) }
    }

    private var neighbors: (previous: LocalChapterModel?, next: LocalChapterModel?) {
        foreignPageTitle == nil ? env.store.neighbors(of: current) : (nil, nil)
    }

    private var currentTitle: String {
        if let foreignPageTitle { return foreignPageTitle }
        return ChapterTextFormatter.presentation(storedTitle: current.title,
                                                 urlString: current.urlString).title
    }

    private func open(_ chapter: LocalChapterModel) {
        foreignTitleTask?.cancel()
        foreignPageTitle = nil
        current = chapter
        targetProgress = chapter.readingProgress
        if let url = URL(string: chapter.urlString) {
            env.reader.load(url)
        }
    }

    /// Patreon navigates between posts client-side (SPA), so didFinish may never fire.
    /// Keep `current` in sync with whatever article the web view actually shows.
    /// Pages outside the library (e.g. not-yet-imported related posts) get a
    /// "foreign" state: the title comes from the page itself, prev/next navigation
    /// is hidden, and no stored progress is applied to them.
    private func syncCurrentChapter(to url: URL?) {
        guard let url else { return }
        if let chapter = env.store.chapter(withPageURL: url.absoluteString) {
            foreignTitleTask?.cancel()
            foreignPageTitle = nil
            guard chapter.id != current.id else { return }
            current = chapter
            targetProgress = chapter.readingProgress
            applyReaderTreatment()
        } else {
            targetProgress = nil
            let staleTitles: Set<String> = [current.title, currentTitle]
            let slugTitle = ChapterTextFormatter.presentation(storedTitle: "",
                                                              urlString: url.absoluteString).title
            foreignPageTitle = slugTitle.isEmpty ? "Patreon post" : slugTitle
            pollForeignTitle(rejecting: staleTitles)
        }
    }

    /// The SPA may still render the previous post for a moment after the URL changes,
    /// so poll briefly and keep the latest title the page settles on. Titles matching
    /// the chapter we navigated away from are ignored.
    private func pollForeignTitle(rejecting staleTitles: Set<String>) {
        foreignTitleTask?.cancel()
        foreignTitleTask = Task { @MainActor in
            for _ in 0..<8 {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled, foreignPageTitle != nil else { return }
                env.reader.webView.evaluateJavaScript(Self.readerTitleScript) { result, _ in
                    Task { @MainActor in
                        guard foreignPageTitle != nil,
                              let title = result as? String, !title.isEmpty,
                              !staleTitles.contains(title) else { return }
                        foreignPageTitle = title
                    }
                }
            }
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
        // Foreign pages have no library chapter to repair or restore progress for.
        guard foreignPageTitle == nil else { return }
        repairCurrentTitleIfNeeded(webView)
        let restorable = targetProgress.flatMap { ReaderProgressPolicy.shouldRestore($0) ? $0 : nil }
        webView.evaluateJavaScript(ReaderStyler.enforceScrollScript(progress: restorable),
                                   completionHandler: nil)
    }

    private func repairCurrentTitleIfNeeded(_ webView: WKWebView) {
        guard ChapterTextFormatter.isProbablyContaminatedTitle(current.title) else { return }
        webView.evaluateJavaScript(Self.readerTitleScript) { result, _ in
            guard let title = result as? String, !title.isEmpty,
                  !ChapterTextFormatter.isProbablyContaminatedTitle(title)
            else { return }
            Task { @MainActor in
                env.store.rename(current, to: title)
            }
        }
    }

    private static let readerTitleScript = """
    (function () {
      function compact(value) {
        return (value || "").replace(/\\s+/g, " ").trim();
      }
      function candidate(value) {
        var text = compact(value);
        return text && text.length <= 180 ? text : "";
      }
      var selectors = ['[data-tag="post-title"]', '[data-testid="post-title"]', 'article h1', 'h1'];
      for (var i = 0; i < selectors.length; i++) {
        var node = document.querySelector(selectors[i]);
        var title = candidate(node && node.textContent);
        if (title) { return title; }
      }
      return candidate((document.title || "").replace(/\\s*\\|\\s*Patreon.*$/i, ""));
    })();
    """

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: { Image(systemName: "chevron.down") }
                .accessibilityLabel("Close reader")
            Spacer()
            Text(currentTitle).font(.subheadline.weight(.medium)).lineLimit(1)
                .accessibilityIdentifier("smoke.readerTitle")
            Spacer()
            Menu {
                Button("Increase font") { prefs.fontSize = min(32, prefs.fontSize + 1) }
                Button("Decrease font") { prefs.fontSize = max(14, prefs.fontSize - 1) }
                Toggle("Reader mode", isOn: $prefs.readerModeEnabled)
                if let url = env.reader.currentURL ?? URL(string: current.urlString) {
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
        HStack(spacing: 8) {
            if let previous = neighbors.previous {
                Button { open(previous) } label: {
                    Label("上一章", systemImage: "chevron.left")
                }
            } else {
                // Color is greedy in both axes; without a height the bar grows to fill the screen.
                Color.clear.frame(width: 72, height: 0)
            }
            Text(currentTitle)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
            if let next = neighbors.next {
                Button { open(next) } label: {
                    HStack {
                        Text("下一章")
                        Image(systemName: "chevron.right")
                    }
                }
            } else {
                Color.clear.frame(width: 72, height: 0)
            }
        }
        .font(.subheadline)
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }
}
