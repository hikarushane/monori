import Foundation

public enum ReaderStyler {
    public static let styleElementID = "chapterly-reader-style"

    public static func ruleset() -> String {
        guard let url = Bundle.module.url(forResource: "ReaderRuleset", withExtension: "css"),
              let css = try? String(contentsOf: url, encoding: .utf8) else {
            assertionFailure("Missing ReaderRuleset.css")
            return ""
        }
        return css
    }

    public static func injectionScript() -> String {
        let css = ruleset()
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "${", with: "\\${")
        return """
        (function () {
          var old = document.getElementById("\(styleElementID)");
          if (old) { old.remove(); }
          var style = document.createElement("style");
          style.id = "\(styleElementID)";
          style.textContent = `\(css)`;
          document.documentElement.appendChild(style);
        })();
        """
    }

    public static func removalScript() -> String {
        """
        (function () {
          var old = document.getElementById("\(styleElementID)");
          if (old) { old.remove(); }
        })();
        """
    }

    public static func fontSizeScript(points: Int) -> String {
        let clamped = min(32, max(14, points))
        return "document.documentElement.style.setProperty('--chapterly-font-size', '\(clamped)px');"
    }

    public static func lineHeightScript(value: Double) -> String {
        let clamped = min(2.4, max(1.2, value))
        let formatted = String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), clamped)
        return "document.documentElement.style.setProperty('--chapterly-line-height', '\(formatted)');"
    }

    /// Full HTML document wrapper for stored chapter HTML (Google Docs import).
    /// Google Docs export inline `font-size`/`line-height` on every paragraph and
    /// span, which beats a plain `body` rule — so the reader's prefs never reach
    /// the prose. The descendant rules below use `!important` so the CSS
    /// variables (also updated live by `fontSizeScript`/`lineHeightScript`) win
    /// over Google's inline styles. Headings keep their own size for hierarchy.
    public static func wrappedDocument(inner: String, fontSizePoints: Int, lineHeight: Double) -> String {
        let size = min(32, max(14, fontSizePoints))
        let lh = String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"),
                        min(2.4, max(1.2, lineHeight)))
        return """
        <!doctype html><html><head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta name="color-scheme" content="light dark">
        <style>
          :root { color-scheme: light dark; --chapterly-font-size: \(size)px; --chapterly-line-height: \(lh); }
          html, body { background: Canvas; }
          body { margin: 0; padding: 16px 18px; color: CanvasText;
                 font-family: -apple-system, "PingFang TC", "Heiti TC", sans-serif;
                 word-break: break-word; }
          /* Google Docs mobilebasic exports inline color:#000000 and
             background-color:#ffffff on every paragraph and span.
             Override them so the page adapts to light/dark mode. */
          * { color: CanvasText !important; background-color: transparent !important; }
          html, body { background: Canvas !important; }
          /* Resize prose and everything inside it, but NOT <h1>-<h6> or their
             children, so chapter sub-headings keep their relative size. A bare
             `body span` rule would flatten Google headings, whose text is
             wrapped in <span> (<h2><span style="font-size:12pt">…). */
          body,
          body p, body p *,
          body li, body li *,
          body blockquote, body blockquote *,
          body td, body td * {
            font-size: var(--chapterly-font-size) !important;
            line-height: var(--chapterly-line-height) !important;
          }
          img { max-width: 100%; height: auto; }
        </style></head><body>\(inner)</body></html>
        """
    }

    /// Pins the scroll position to `progress` (or top when nil) for a few seconds,
    /// re-applying every 400ms to defeat Patreon's own auto-scroll. Stops as soon
    /// as the user touches or wheel-scrolls the page.
    public static func enforceScrollScript(progress: Double?) -> String {
        let target = progress.map { min(1.0, max(0.0, $0)) } ?? 0.0
        return """
        (function () {
          var target = \(target);
          var until = Date.now() + 4000;
          if (!window.__chapterlyInteractionHook) {
            window.__chapterlyInteractionHook = true;
            var mark = function () { window.__chapterlyUserInteracted = true; };
            window.addEventListener("touchstart", mark, { passive: true });
            window.addEventListener("wheel", mark, { passive: true });
          }
          window.__chapterlyUserInteracted = false;
          if (window.__chapterlyScrollEnforcer) {
            clearInterval(window.__chapterlyScrollEnforcer);
          }
          function apply() {
            var doc = document.documentElement;
            var max = doc.scrollHeight - window.innerHeight;
            window.scrollTo(0, max > 0 ? max * target : 0);
          }
          apply();
          window.__chapterlyScrollEnforcer = setInterval(function () {
            if (window.__chapterlyUserInteracted === true || Date.now() > until) {
              clearInterval(window.__chapterlyScrollEnforcer);
              window.__chapterlyScrollEnforcer = null;
              return;
            }
            apply();
          }, 400);
        })();
        """
    }
}
