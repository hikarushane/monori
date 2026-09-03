import SwiftUI
import WebKit
import MonoriCore

struct ReaderView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @Environment(\.bottomNavigationHeight) private var bottomNavigationHeight
    @Environment(\.monoriUIMetrics) private var metrics
    @State private var current: LocalChapterModel
    /// Reader chrome (top/bottom bars) is hidden by default; tapping the
    /// center of the page toggles it.
    @State private var chromeVisible = false
    @State private var showPrefsPanel = false
    @State private var showImportConfirmation = false
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
                                     lineHeight: prefs.lineSpacing,
                                     font: env.resolvedFontCSS())
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                MonoriPalette.canvas
                    .ignoresSafeArea()

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
            }
                .overlay(alignment: .top) { topChrome }
                .overlay(alignment: .bottom) {
                    bottomChrome(bottomInset: proxy.safeAreaInsets.bottom)
                }
                .overlay(alignment: .top) { swipeTopIndicator }
                .overlay(alignment: .bottom) { swipeBottomIndicator }
                .overlay {
                    if showImportConfirmation {
                        ImportConfirmationOverlay(importedCount: env.importedCountThisSession) {
                            showImportConfirmation = false
                        }
                        .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: showImportConfirmation)
                .onAppear { open(current) }
                .onDisappear {
                    saveScrollPosition()
                    foreignTitleTask?.cancel()
                }
                .onChange(of: env.reader.finishedNavigationCount) { _, _ in applyReaderTreatment() }
                .onChange(of: env.reader.currentURL) { _, newURL in syncCurrentChapter(to: newURL) }
                .onChange(of: prefs.fontSize) { _, _ in applyTypography() }
                .onChange(of: prefs.lineSpacing) { _, _ in applyTypography() }
                .onChange(of: prefs.selectedFontID) { _, _ in applyFont() }
                .onChange(of: prefs.chineseConversion) { _, _ in applyChineseConversion() }
        }
        .ignoresSafeArea(edges: .bottom)
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
                    WebCollectionBanner(model: env.reader, showImportConfirmation: $showImportConfirmation)
                }
                if showPrefsPanel {
                    ReaderPreferencesPanel(prefs: prefs)
                }
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    @ViewBuilder private func bottomChrome(bottomInset: CGFloat) -> some View {
        if chromeVisible {
            bottomBar(bottomInset: bottomInset)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func handleContentTap(isCenter: Bool) {
        withAnimation(.easeOut(duration: 0.2)) {
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

    private var chapterProgress: String? {
        guard foreignPageTitle == nil, let collection = current.collection else { return nil }
        let chapters = collection.chapters.sorted {
            ChapterOrdering.sortKey(urlString: $0.urlString, orderIndex: $0.orderIndex)
                < ChapterOrdering.sortKey(urlString: $1.urlString, orderIndex: $1.orderIndex)
        }
        guard let index = chapters.firstIndex(where: { $0.id == current.id }) else { return nil }
        return "\(index + 1) / \(chapters.count)"
    }

    private func saveScrollPosition() {
        guard foreignPageTitle == nil else { return }
        let chapter = current
        Task { @MainActor in
            let result = try? await env.reader.webView.evaluateJavaScript(ReaderStyler.captureScrollProgressScript)
            let progress = (result as? NSNumber)?.doubleValue
            env.store.saveReadingProgress(progress, for: chapter)
        }
    }

    private func open(_ chapter: LocalChapterModel) {
        if env.reader.currentURL != nil {
            saveScrollPosition()
        }
        foreignTitleTask?.cancel()
        foreignPageTitle = nil
        foreignPageKey = nil
        current = chapter
        env.store.recordChapterOpened(chapter)
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
                env.store.recordChapterOpened(chapter)
                applyReaderTreatment()
            } else if wasForeign {
                // SPA return to the chapter we were already on: didFinish never fires,
                // so re-apply treatment here or the page keeps Patreon's auto-scroll.
                applyReaderTreatment()
            }
        } else if let threadID = URLNormalizer.slashtwThreadID(url),
                  let currentURL = URL(string: current.urlString),
                  URLNormalizer.slashtwThreadID(currentURL) == threadID {
            // slashtw chapters share the same thread URL; the WebView drops the
            // #post{id} fragment so chapter(withPageURL:) can't distinguish them.
            // Keep current (set by open()) and ensure reader treatment fires.
            foreignTitleTask?.cancel()
            if foreignPageTitle != nil {
                foreignPageTitle = nil
                foreignPageKey = nil
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
                Task { @MainActor in
                    let result = try? await env.reader.webView.evaluateJavaScript(Self.readerTitleScript)
                    guard foreignPageTitle != nil,
                          let title = result as? String, !title.isEmpty,
                          !staleTitles.contains(title) else { return }
                    foreignPageTitle = title
                }
            }
        }
    }

    // MARK: - Page treatment

    private func applyReaderTreatment() {
        guard env.reader.currentURL != nil else { return }
        let webView = env.reader.webView
        Task { @MainActor in
            if foreignPageTitle == nil {
                await applyCurrentPreferences(to: webView)
                if !renderingStoredHTML {
                    let sourceKind = current.collection?.sourceKind ?? .patreon
                    switch sourceKind {
                    case .vocus:
                        _ = try? await webView.evaluateJavaScript(ReaderStyler.vocusInjectionScript())
                    case .asianFanfics:
                        _ = try? await webView.evaluateJavaScript(ReaderStyler.affInjectionScript())
                    case .cxc:
                        _ = try? await webView.evaluateJavaScript(ReaderStyler.cxcInjectionScript())
                    case .slashtw:
                        _ = try? await webView.evaluateJavaScript(ReaderStyler.slashtwInjectionScript())
                    default:
                        _ = try? await webView.evaluateJavaScript(ReaderStyler.injectionScript())
                    }
                }
                if metrics.isRegularWidth {
                    _ = try? await webView.evaluateJavaScript(
                        ReaderStyler.iPadReaderLayoutScript())
                }
                await applyCurrentPreferences(to: webView)
                if metrics.isRegularWidth && !renderingStoredHTML {
                    _ = try? await webView.evaluateJavaScript(
                        ReaderStyler.iPadDelayedPrefsScript(
                            fontSize: prefs.fontSize,
                            lineSpacing: prefs.lineSpacing))
                }
                // Spawns own Task — does not block enforceScroll (title repair is independent of scroll)
                repairCurrentTitleIfNeeded(webView)
            } else {
                DiagnosticLog.shared.log(category: "reader",
                    "foreign page — reader CSS removed")
                _ = try? await webView.evaluateJavaScript(ReaderStyler.removalScript())
            }
            let savedProgress = foreignPageTitle == nil ? current.readingProgress : nil
            _ = try? await webView.evaluateJavaScript(
                ReaderStyler.enforceScrollScript(progress: savedProgress))
        }
    }

    private func applyCurrentPreferences(to webView: WKWebView) async {
        let fontCSS = env.resolvedFontCSS()
        _ = try? await webView.evaluateJavaScript(
            ReaderStyler.fontFamilyScript(font: fontCSS))
        _ = try? await webView.evaluateJavaScript(
            ReaderStyler.fontSizeScript(points: prefs.fontSize))
        _ = try? await webView.evaluateJavaScript(
            ReaderStyler.lineHeightScript(value: prefs.lineSpacing))
    }

    /// Applies the current font-size/line-spacing prefs to the web view.
    /// Called via the `.onChange(of: prefs.fontSize/lineSpacing)` modifiers
    /// on every prefs-panel tap (or Settings stepper change) so the text
    /// resizes immediately.
    private func applyTypography() {
        let webView = env.reader.webView
        Task { @MainActor in
            _ = try? await webView.evaluateJavaScript(
                ReaderStyler.fontSizeScript(points: prefs.fontSize))
            _ = try? await webView.evaluateJavaScript(
                ReaderStyler.lineHeightScript(value: prefs.lineSpacing))
        }
    }

    private func applyFont() {
        let webView = env.reader.webView
        let expectedID = prefs.selectedFontID
        let fontCSS = env.resolvedFontCSS()
        Task { @MainActor in
            guard prefs.selectedFontID == expectedID else { return }
            _ = try? await webView.evaluateJavaScript(
                ReaderStyler.fontFamilyScript(font: fontCSS))
        }
    }

    private func applyChineseConversion() {
        let webView = env.reader.webView
        let mode = prefs.chineseConversion
        let mapString: String
        switch mode {
        case .off: mapString = ""
        case .toTraditional: mapString = ChineseConversionMap.shared.s2tMap
        case .toSimplified: mapString = ChineseConversionMap.shared.t2sMap
        }
        Task { @MainActor in
            _ = try? await webView.evaluateJavaScript(
                ReaderStyler.chineseConversionScript(mode: mode, mapString: mapString))
        }
    }

    private func repairCurrentTitleIfNeeded(_ webView: WKWebView) {
        guard ChapterTextFormatter.isProbablyContaminatedTitle(current.title) else { return }
        Task { @MainActor in
            let result = try? await webView.evaluateJavaScript(Self.readerTitleScript)
            guard let title = result as? String, !title.isEmpty,
                  !ChapterTextFormatter.isProbablyContaminatedTitle(title)
            else { return }
            env.store.rename(current, to: title)
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
        HStack(spacing: 4) {
            Button {
                dismissSlidingRight()
            } label: {
                Image(systemName: "chevron.left")
                    .font(MonoriTypography.ui(metrics.primaryActionIconSize,
                                               relativeTo: .body, weight: .semibold))
                    .foregroundStyle(readerChromeIconColor)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("返回書庫")
            #if DEBUG
            .accessibilityIdentifier("smoke.readerDismissButton")
            #endif
            if foreignPageTitle == nil {
                Button {
                    env.store.toggleBookmark(current)
                    DiagnosticLog.shared.log(category: "bookmark",
                        "reader bookmark \(current.isBookmarked ? "set" : "cleared")")
                } label: {
                    Image(systemName: current.isBookmarked ? "bookmark.fill" : "bookmark")
                        .font(MonoriTypography.ui(metrics.primaryActionIconSize,
                                                   relativeTo: .body, weight: .medium))
                        .foregroundStyle(current.isBookmarked ? MonoriPalette.bookmark : readerChromeIconColor)
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
                withAnimation(.easeOut(duration: 0.2)) { showPrefsPanel.toggle() }
            } label: {
                Image(systemName: "textformat.size")
                    .font(MonoriTypography.ui(metrics.primaryActionIconSize,
                                               relativeTo: .body, weight: .semibold))
                    .foregroundStyle(readerChromeIconColor)
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
                .font(MonoriTypography.ui(metrics.bodyFontSize,
                                           relativeTo: .headline, weight: .medium))
                .tracking(MonoriTypography.uiTracking)
                .foregroundStyle(readerChromeTitleColor)
                .lineLimit(1)
                .padding(.horizontal, 100)
                .allowsHitTesting(false)
                .accessibilityIdentifier("smoke.readerTitle")
        }
        .padding(.horizontal, MonoriSpacing.x2)
        .frame(height: metrics.readerTopBarHeight)
        .background(MonoriPalette.canvas)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(MonoriPalette.divider)
                .frame(height: 1)
        }
    }

    private func bottomBar(bottomInset: CGFloat) -> some View {
        HStack(spacing: MonoriSpacing.x2) {
            if let previous = neighbors.previous {
                Button { open(previous) } label: {
                    HStack(spacing: MonoriSpacing.x1) {
                        Image(systemName: "chevron.left")
                            .font(MonoriTypography.ui(metrics.actionIconSize,
                                                       relativeTo: .body, weight: .semibold))
                        Text("上一章")
                            .font(MonoriTypography.ui(metrics.buttonLabelFontSize,
                                                       relativeTo: .subheadline, weight: .medium))
                            .tracking(MonoriTypography.uiTracking)
                    }
                    .foregroundStyle(MonoriPalette.ink)
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 88, height: 0)
            }
            Spacer(minLength: 0)
            if let next = neighbors.next {
                Button { open(next) } label: {
                    HStack(spacing: MonoriSpacing.x1) {
                        Text("下一章")
                            .font(MonoriTypography.ui(metrics.buttonLabelFontSize,
                                                       relativeTo: .subheadline, weight: .medium))
                            .tracking(MonoriTypography.uiTracking)
                        Image(systemName: "chevron.right")
                            .font(MonoriTypography.ui(metrics.actionIconSize,
                                                       relativeTo: .body, weight: .semibold))
                    }
                    .foregroundStyle(MonoriPalette.ink)
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 88, height: 0)
            }
        }
        .overlay {
            if let chapterProgress {
                Text(chapterProgress)
                    .font(MonoriTypography.ui(metrics.chapterProgressFontSize, relativeTo: .footnote, weight: .regular))
                    .tracking(MonoriTypography.uiTracking)
                    .foregroundStyle(MonoriPalette.secondaryInk)
                    .monospacedDigit()
                    .allowsHitTesting(false)
            }
        }
        .padding(.horizontal, MonoriSpacing.x3 + 20)
        .frame(height: bottomNavigationHeight + bottomInset)
        .background(MonoriPalette.canvas)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(MonoriPalette.divider)
                .frame(height: 1)
        }
    }

    private var readerChromeTitleColor: Color {
        MonoriPalette.ink
    }

    private var readerChromeIconColor: Color {
        MonoriPalette.ink
    }

}
