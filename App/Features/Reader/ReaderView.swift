import SwiftUI
import WebKit
import ChapterlyCore

struct ReaderView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var current: LocalChapterModel
    @State private var prefs = ReaderPreferences()
    /// Reader chrome (top/bottom bars) is hidden by default; tapping the
    /// center of the page toggles it.
    @State private var chromeVisible = false
    @State private var showPrefsPanel = false
    /// Non-nil while the web view shows a page outside the library (e.g. a related
    /// post from a collection that has not been imported). Holds the display title.
    @State private var foreignPageTitle: String?
    @State private var foreignTitleTask: Task<Void, Never>?
    /// Identity of the foreign page currently shown (post ID when available),
    /// so SPA URL rewrites on the same page don't re-pin the scroll position.
    @State private var foreignPageKey: String?

    init(chapter: LocalChapterModel) {
        _current = State(initialValue: chapter)
    }

    var body: some View {
        PatreonWebView(model: env.reader,
                       onContentTap: handleContentTap(isCenter:),
                       backSwipeOverride: handleBackSwipe)
            .accessibilityIdentifier("smoke.readerWebView")
            .overlay(alignment: .top) { topChrome }
            .overlay(alignment: .bottom) { bottomChrome }
            .onAppear { open(current) }
            .onDisappear { foreignTitleTask?.cancel() }
            .onChange(of: env.reader.finishedNavigationCount) { _, _ in applyReaderTreatment() }
            .onChange(of: env.reader.currentURL) { _, newURL in syncCurrentChapter(to: newURL) }
            .onChange(of: prefs.fontSize) { _, size in
                env.reader.webView.evaluateJavaScript(
                    ReaderStyler.fontSizeScript(points: size), completionHandler: nil)
            }
            .onChange(of: prefs.lineSpacing) { _, spacing in
                env.reader.webView.evaluateJavaScript(
                    ReaderStyler.lineHeightScript(value: spacing), completionHandler: nil)
            }
    }

    // MARK: - Chrome

    @ViewBuilder private var topChrome: some View {
        if chromeVisible {
            VStack(spacing: 0) {
                topBar
                if foreignPageTitle != nil {
                    WebCollectionBanner(model: env.reader)
                }
                if showPrefsPanel {
                    ReaderPreferencesPanel(prefs: prefs)
                }
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    @ViewBuilder private var bottomChrome: some View {
        if chromeVisible {
            bottomBar
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func handleContentTap(isCenter: Bool) {
        withAnimation(.easeInOut(duration: 0.25)) {
            if showPrefsPanel {
                // Any tap on the page outside the panel closes just the panel.
                showPrefsPanel = false
            } else if isCenter {
                chromeVisible.toggle()
            }
        }
    }

    /// Left-edge swipe: a foreign page first goes back toward the chapter it
    /// was opened from; on a library chapter the swipe leaves the reader.
    private func handleBackSwipe() {
        if foreignPageTitle != nil && env.reader.webView.canGoBack {
            env.reader.webView.goBack()
        } else {
            dismiss()
        }
    }

    // MARK: - Navigation / state sync

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
        foreignPageKey = nil
        current = chapter
        if let url = URL(string: chapter.urlString) {
            env.reader.load(url)
        }
    }

    /// Patreon navigates between posts client-side (SPA), so didFinish may never fire.
    /// Keep `current` in sync with whatever article the web view actually shows.
    /// Pages outside the library (e.g. not-yet-imported related posts) get a
    /// "foreign" state: the title comes from the page itself and prev/next
    /// navigation is hidden.
    private func syncCurrentChapter(to url: URL?) {
        guard let url else { return }
        if let chapter = env.store.chapter(withPageURL: url.absoluteString) {
            foreignTitleTask?.cancel()
            let wasForeign = foreignPageTitle != nil
            foreignPageTitle = nil
            foreignPageKey = nil
            if chapter.id != current.id {
                current = chapter
                applyReaderTreatment()
            } else if wasForeign {
                // SPA return to the chapter we were already on: didFinish never fires,
                // so re-apply treatment here or the page keeps Patreon's auto-scroll.
                applyReaderTreatment()
            }
        } else {
            let key = URLNormalizer.patreonPostID(url.absoluteString)
                ?? URLNormalizer.normalize(url.absoluteString)?.absoluteString
                ?? url.absoluteString
            let samePage = foreignPageTitle != nil && key == foreignPageKey
            foreignPageKey = key
            guard !samePage else { return }
            let staleTitles: Set<String> = [current.title, currentTitle]
            let slugTitle = ChapterTextFormatter.presentation(storedTitle: "",
                                                              urlString: url.absoluteString).title
            foreignPageTitle = slugTitle.isEmpty ? "Patreon post" : slugTitle
            applyReaderTreatment()
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
                // The one-shot collection detect can race the SPA render; refresh it
                // alongside the title so the series banner reflects the settled page.
                env.reader.runCollectionDetect()
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

    // MARK: - Page treatment

    private func applyReaderTreatment() {
        guard env.reader.currentURL != nil else { return }
        let webView = env.reader.webView
        if foreignPageTitle == nil {
            webView.evaluateJavaScript(ReaderStyler.injectionScript(), completionHandler: nil)
            webView.evaluateJavaScript(ReaderStyler.fontSizeScript(points: prefs.fontSize),
                                       completionHandler: nil)
            webView.evaluateJavaScript(ReaderStyler.lineHeightScript(value: prefs.lineSpacing),
                                       completionHandler: nil)
            repairCurrentTitleIfNeeded(webView)
        } else {
            // The ruleset is post-page specific: on creator/collection pages it
            // hides the chrome and squeezes the feed, so strip it there.
            webView.evaluateJavaScript(ReaderStyler.removalScript(), completionHandler: nil)
        }
        // Every page opens at the top; the enforcer also defeats Patreon's own
        // auto-scroll on freshly loaded pages.
        webView.evaluateJavaScript(ReaderStyler.enforceScrollScript(progress: nil),
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

    // MARK: - Bars

    private var topBar: some View {
        HStack {
            #if DEBUG
            // Debug-only exit hatch for automated UI agents: idb cannot fire the
            // left-edge UIScreenEdgePanGestureRecognizer that dismisses this
            // .fullScreenCover, so expose a tappable close button. Never shipped
            // in Release. No `chromeVisible` check needed — the whole top bar is
            // rendered only when `chromeVisible == true` (see `topChrome`).
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close reader")
            .accessibilityIdentifier("smoke.readerDismissButton")
            #endif
            if foreignPageTitle == nil {
                Button {
                    env.store.toggleBookmark(current)
                } label: {
                    Image(systemName: current.isBookmarked ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(current.isBookmarked ? Color.accentColor : Color.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(current.isBookmarked ? "Remove bookmark" : "Bookmark this chapter")
                .accessibilityIdentifier("smoke.readerBookmarkButton")
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
            Spacer()
            Text(currentTitle).font(.subheadline.weight(.medium)).lineLimit(1)
                .accessibilityIdentifier("smoke.readerTitle")
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { showPrefsPanel.toggle() }
            } label: {
                Image(systemName: "textformat.size")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Reading options")
            .accessibilityIdentifier("smoke.readerPrefsButton")
        }
        .padding(.horizontal, 4)
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
