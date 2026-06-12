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

    public static func restoreScrollScript(progress: Double) -> String {
        let clamped = min(1.0, max(0.0, progress))
        return """
        (function () {
          var doc = document.documentElement;
          var max = doc.scrollHeight - window.innerHeight;
          if (max > 0) { window.scrollTo(0, max * \(clamped)); }
        })();
        """
    }

    public static func scrollToTopScript() -> String {
        "window.scrollTo(0, 0);"
    }

    /// Pins the scroll position to `progress` (or top when nil) for a few seconds,
    /// re-applying every 400ms to defeat Patreon's own auto-scroll. Stops as soon as
    /// the user touches or wheel-scrolls the page. Also resets the shared interaction
    /// flag so ProgressTracker ignores non-user scrolls after each navigation.
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
