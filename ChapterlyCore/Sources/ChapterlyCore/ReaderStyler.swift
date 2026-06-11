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
}
