import SwiftUI
import WebKit
import MonoriCore

struct ReaderView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var current: LocalChapterModel
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
    /// True while the web view is showing a stored-HTML chapter (Google Docs import).
    /// Prevents `syncCurrentChapter` from trying to match a URL that was never loaded.
    @State private var renderingStoredHTML = false
    /// The edge being overscrolled (.top or .bottom), nil when not overscrolling.
    @State private var swipeEdge: Edge?
    /// Pull progress in 0…1 toward the chapter-navigation activation threshold.
    @State private var swipeProgress: CGFloat = 0

    init(chapter: LocalChapterModel) {
        _current = State(initialValue: chapter)
    }

    private var prefs: ReaderPreferences { env.prefs }

    private func wrappedHTML(_ inner: String) -> String {
        ReaderStyler.wrappedDocument(inner: inner,
                                     fontSizePoints: prefs.fontSize,
                                     lineHeight: prefs.lineSpacing)
    }

    var body: some View {
        PatreonWebView(model: env.reader,
                       onContentTap: handleContentTap(isCenter:),
                       backSwipeOverride: handleBackSwipe,
                       onOverscroll: { edge, progress in
                           swipeEdge = edge
                           swipeProgress = progress
                       },
                       onChapterBoundary: { edge in
                           withAnimation(.easeInOut(duration: 0.3)) {
                               swipeEdge = nil
                               swipeProgress = 0
                           }
                           switch edge {
                           case .top:
                               if let prev = neighbors.previous { open(prev) }
                           case .bottom:
                               if let next = neighbors.next { open(next) }
                           default: break
                           }
                       })
            .accessibilityIdentifier("smoke.readerWebView")
            .overlay(alignment: .top) { topChrome }
            .overlay(alignment: .bottom) { bottomChrome }
            .overlay(alignment: .top) { swipeTopIndicator }
            .overlay(alignment: .bottom) { swipeBottomIndicator }
            .onAppear { open(current) }
            .onDisappear { foreignTitleTask?.cancel() }
            .onChange(of: env.reader.finishedNavigationCount) { _, _ in applyReaderTreatment() }
            .onChange(of: env.reader.currentURL) { _, newURL in syncCurrentChapter(to: newURL) }
            .onChange(of: prefs.fontSize) { _, _ in applyTypography() }
            .onChange(of: prefs.lineSpacing) { _, _ in applyTypography() }
    }

    // MARK: - Chapter swipe indicators

    @ViewBuilder private var swipeTopIndicator: some View {
        if swipeEdge == Edge.top, let prev = neighbors.previous {
            ChapterSwipeIndicator(
                title: ChapterTextFormatter.presentation(storedTitle: prev.title,
                                                         urlString: prev.urlString).title,
                edge: Edge.top,
                progress: swipeProgress)
                .padding(.top, 60)
        }
    }

    @ViewBuilder private var swipeBottomIndicator: some View {
        if swipeEdge == Edge.bottom, let next = neighbors.next {
            ChapterSwipeIndicator(
                title: ChapterTextFormatter.presentation(storedTitle: next.title,
                                                         urlString: next.urlString).title,
                edge: Edge.bottom,
                progress: swipeProgress)
                .padding(.bottom, 60)
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

    /// Left-edge swipe: a foreign page first goes back toward the chapter it was
    /// opened from; on a library chapter the swipe leaves the reader, sliding the
    /// page off to the right so it reads as a "pop" matching the gesture
    /// direction instead of the cover's default downward collapse.
    private func handleBackSwipe() {
        if foreignPageTitle != nil && env.reader.webView.canGoBack {
            env.reader.webView.goBack()
        } else {
            dismissSlidingRight()
        }
    }

    private func dismissSlidingRight() {
        guard let window = env.reader.webView.window,
              let snapshot = window.snapshotView(afterScreenUpdates: false) else {
            dismiss()
            return
        }
        // Defensive: drop any snapshot a previous dismissal left behind.
        window.viewWithTag(Self.slideSnapshotTag)?.removeFromSuperview()
        snapshot.tag = Self.slideSnapshotTag
        snapshot.frame = window.bounds
        window.addSubview(snapshot)

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { dismiss() }

        UIView.animate(withDuration: 0.28, delay: 0, options: [.curveEaseInOut]) {
            snapshot.frame.origin.x = window.bounds.width
        } completion: { _ in
            snapshot.removeFromSuperview()
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
        if let html = chapter.contentHTML {
            renderingStoredHTML = true
            let base = URL(string: chapter.urlString.components(separatedBy: "#").first ?? chapter.urlString)
            env.reader.webView.loadHTMLString(wrappedHTML(html), baseURL: base)
        } else {
            renderingStoredHTML = false
            if let url = URL(string: chapter.urlString) {
                env.reader.load(url)
            }
        }
    }

    /// Patreon navigates between posts client-side (SPA), so didFinish may never fire.
    /// Keep `current` in sync with whatever article the web view actually shows.
    /// Pages outside the library (e.g. not-yet-imported related posts) get a
    /// "foreign" state: the title comes from the page itself and prev/next
    /// navigation is hidden.
    private func syncCurrentChapter(to url: URL?) {
        if renderingStoredHTML { return }
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
            let fallback: String = {
                let s = url.absoluteString
                if URLNormalizer.isVocusHost(s) { return "Vocus" }
                return "Patreon post"
            }()
            foreignPageTitle = slugTitle.isEmpty ? fallback : slugTitle
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
            if !renderingStoredHTML {
                let sourceKind = current.collection?.sourceKind ?? .patreon
                switch sourceKind {
                case .vocus:
                    webView.evaluateJavaScript(ReaderStyler.vocusInjectionScript(), completionHandler: nil)
                case .asianFanfics:
                    webView.evaluateJavaScript(ReaderStyler.affInjectionScript(), completionHandler: nil)
                default:
                    webView.evaluateJavaScript(ReaderStyler.injectionScript(), completionHandler: nil)
                }
            }
            applyTypography()
            repairCurrentTitleIfNeeded(webView)
        } else {
            webView.evaluateJavaScript(ReaderStyler.removalScript(), completionHandler: nil)
        }
        webView.evaluateJavaScript(ReaderStyler.enforceScrollScript(progress: nil),
                                   completionHandler: nil)
    }

    /// Applies the current font-size/line-spacing prefs to the web view. Called
    /// via the `.onChange(of: prefs.fontSize/lineSpacing)` modifiers below on
    /// every prefs-panel tap (or Settings stepper change) so the text resizes
    /// immediately, and from `applyReaderTreatment()` on every fresh page
    /// load/navigation so a newly opened chapter reflects the saved prefs.
    private func applyTypography() {
        let webView = env.reader.webView
        webView.evaluateJavaScript(ReaderStyler.fontSizeScript(points: prefs.fontSize),
                                   completionHandler: nil)
        webView.evaluateJavaScript(ReaderStyler.lineHeightScript(value: prefs.lineSpacing),
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

    /// Tag for the transient slide-dismiss snapshot, so a leftover one (a
    /// device-only teardown race) can be found and removed before it veils the
    /// next reader open.
    private static let slideSnapshotTag = 778_899

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
        HStack(spacing: 0) {
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
            .accessibilityLabel("關閉閱讀器")
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
                .accessibilityLabel(current.isBookmarked ? "移除書籤" : "加入書籤")
                .accessibilityIdentifier("smoke.readerBookmarkButton")
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
            Spacer(minLength: 0)
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { showPrefsPanel.toggle() }
            } label: {
                Image(systemName: "textformat.size")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("閱讀選項")
            .accessibilityIdentifier("smoke.readerPrefsButton")
        }
        // Title is centered to the bar's full width (== screen center / Dynamic
        // Island), independent of the leading/trailing control widths. Horizontal
        // padding keeps it clear of the side buttons; it never intercepts taps.
        .overlay {
            Text(currentTitle)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .padding(.horizontal, 96)
                .allowsHitTesting(false)
                .accessibilityIdentifier("smoke.readerTitle")
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
            Spacer(minLength: 0)
            if let next = neighbors.next {
                Button { open(next) } label: {
                    HStack(spacing: 4) {
                        Text("下一章")
                        Image(systemName: "chevron.right")
                    }
                }
            } else {
                Color.clear.frame(width: 72, height: 0)
            }
        }
        // Center the title to the bar's full width (screen center), independent of
        // the differing prev/next button widths. Padding keeps it clear of them.
        .overlay {
            Text(currentTitle)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .padding(.horizontal, 96)
                .allowsHitTesting(false)
        }
        .font(.subheadline)
        .padding(.horizontal)
        .padding(.vertical, 10)
        // Extend the bar material down through the home-indicator safe area so it
        // reads as docked to the screen bottom; the buttons stay above the inset.
        .background { Rectangle().fill(.bar).ignoresSafeArea(edges: .bottom) }
    }
}
