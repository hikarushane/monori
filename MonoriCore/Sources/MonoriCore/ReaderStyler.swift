import Foundation

public enum ReaderStyler {
    public static let styleElementID = "monori-reader-style"

    public static func ruleset() -> String {
        guard let url = Bundle.module.url(forResource: "ReaderRuleset", withExtension: "css"),
              let css = try? String(contentsOf: url, encoding: .utf8) else {
            assertionFailure("Missing ReaderRuleset.css")
            return ""
        }
        return css
    }

    private static let fontCheckSnippet = """
          document.fonts.ready.then(function () {
            var ok = document.fonts.check('16px "Source Serif 4"');
            if (!ok) { console.warn('[Monori] Source Serif 4 not available via local()'); }
          });
    """

    private static let clearAncestorBgSnippet = """
          function clearAncestorBg() {
            var c = document.querySelector('[data-tag="post-content"]') ||
                    document.querySelector('.patreon-post-content') ||
                    document.querySelector('article');
            if (c) {
              c.style.setProperty('padding-left', 'clamp(24px, 6vw, 48px)', 'important');
              c.style.setProperty('padding-right', 'clamp(24px, 6vw, 48px)', 'important');
              c.style.setProperty('max-width', '34em', 'important');
              c.style.setProperty('margin-left', 'auto', 'important');
              c.style.setProperty('margin-right', 'auto', 'important');
              var p = c.parentElement;
              while (p && p !== document.documentElement) {
                p.style.setProperty('background-color', 'transparent', 'important');
                p.style.setProperty('padding-left', '0', 'important');
                p.style.setProperty('padding-right', '0', 'important');
                p.style.setProperty('margin-left', '0', 'important');
                p.style.setProperty('margin-right', '0', 'important');
                p = p.parentElement;
              }
            }
          }
          clearAncestorBg();
          setTimeout(clearAncestorBg, 500);
          setTimeout(clearAncestorBg, 1500);
    """

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
        \(fontCheckSnippet)
        \(clearAncestorBgSnippet)
        })();
        """
    }

    public static func vocusRuleset() -> String {
        guard let url = Bundle.module.url(forResource: "VocusReaderRuleset", withExtension: "css"),
              let css = try? String(contentsOf: url, encoding: .utf8) else {
            assertionFailure("Missing VocusReaderRuleset.css")
            return ""
        }
        return css
    }

    public static func vocusInjectionScript() -> String {
        let css = vocusRuleset()
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
        \(fontCheckSnippet)
          function cleanVocusChrome() {
            var content = document.querySelector('.editor-content-block') ||
                          document.querySelector('.lexical-web-theme') ||
                          document.querySelector('article');
            if (content) {
              content.style.setProperty('padding-left', 'clamp(24px, 6vw, 48px)', 'important');
              content.style.setProperty('padding-right', 'clamp(24px, 6vw, 48px)', 'important');
              content.style.setProperty('max-width', '34em', 'important');
              content.style.setProperty('margin-left', 'auto', 'important');
              content.style.setProperty('margin-right', 'auto', 'important');
              var cur = content;
              while (cur.parentElement && cur.parentElement !== document.documentElement) {
                var par = cur.parentElement;
                for (var i = 0; i < par.children.length; i++) {
                  var sib = par.children[i];
                  if (sib !== cur && sib.tagName !== 'STYLE' && sib.tagName !== 'SCRIPT' && sib.tagName !== 'LINK') {
                    sib.style.setProperty('display', 'none', 'important');
                  }
                }
                cur = par;
              }
            }
            var anc = content.parentElement;
            while (anc && anc !== document.documentElement) {
              anc.style.setProperty('padding-left', '0', 'important');
              anc.style.setProperty('padding-right', '0', 'important');
              anc.style.setProperty('margin-left', '0', 'important');
              anc.style.setProperty('margin-right', '0', 'important');
              anc = anc.parentElement;
            }
            var all = document.querySelectorAll('body *');
            for (var j = 0; j < all.length; j++) {
              try {
                var s = window.getComputedStyle(all[j]);
                if (s.position === 'fixed' || s.position === 'sticky') {
                  all[j].style.setProperty('display', 'none', 'important');
                }
              } catch(e) {}
            }
            var contentSel = '.editor-content-block, .lexical-web-theme';
            var adBlocks = document.querySelectorAll('div, section, aside');
            for (var k = 0; k < adBlocks.length; k++) {
              var t = (adBlocks[k].textContent || '').trim();
              if (t.length < 200 && t.indexOf('\\u5EE3\\u544A') >= 0) {
                var cb3 = adBlocks[k].closest(contentSel);
                if (cb3) {
                  var w = adBlocks[k];
                  while (w.parentElement !== cb3) w = w.parentElement;
                  w.style.setProperty('display', 'none', 'important');
                } else {
                  adBlocks[k].style.setProperty('display', 'none', 'important');
                }
              }
            }
            var hiddenFrames = document.querySelectorAll('iframe');
            for (var m = 0; m < hiddenFrames.length; m++) {
              var icb = hiddenFrames[m].closest(contentSel);
              if (icb) {
                var ip = hiddenFrames[m];
                while (ip.parentElement !== icb) ip = ip.parentElement;
                ip.style.setProperty('display', 'none', 'important');
              }
            }
          }
          cleanVocusChrome();
          setTimeout(cleanVocusChrome, 1000);
          setTimeout(cleanVocusChrome, 3000);
        })();
        """
    }

    public static func affRuleset() -> String {
        guard let url = Bundle.module.url(forResource: "AFFReaderRuleset", withExtension: "css"),
              let css = try? String(contentsOf: url, encoding: .utf8) else {
            assertionFailure("Missing AFFReaderRuleset.css")
            return ""
        }
        return css
    }

    public static func affInjectionScript() -> String {
        let css = affRuleset()
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
        \(fontCheckSnippet)
          function clearAffAncestors() {
            var c = document.getElementById('bodyText') || document.querySelector('main');
            if (c) {
              c.style.setProperty('padding-left', 'clamp(24px, 6vw, 48px)', 'important');
              c.style.setProperty('padding-right', 'clamp(24px, 6vw, 48px)', 'important');
              c.style.setProperty('max-width', '34em', 'important');
              c.style.setProperty('margin-left', 'auto', 'important');
              c.style.setProperty('margin-right', 'auto', 'important');
              var p = c.parentElement;
              while (p && p !== document.documentElement) {
                p.style.setProperty('padding-left', '0', 'important');
                p.style.setProperty('padding-right', '0', 'important');
                p.style.setProperty('margin-left', '0', 'important');
                p.style.setProperty('margin-right', '0', 'important');
                p = p.parentElement;
              }
            }
          }
          clearAffAncestors();
          setTimeout(clearAffAncestors, 500);
        })();
        """
    }

    private static func affBrowseRuleset() -> String {
        guard let url = Bundle.module.url(forResource: "AFFBrowseRuleset", withExtension: "css"),
              let css = try? String(contentsOf: url, encoding: .utf8) else { return "" }
        return css
    }

    public static func affBrowseInjectionScript() -> String {
        let css = affBrowseRuleset()
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "${", with: "\\${")
        return """
        (function () {
          var id = "monori-browse-style";
          var old = document.getElementById(id);
          if (old) { return; }
          var style = document.createElement("style");
          style.id = id;
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
        return "document.documentElement.style.setProperty('--monori-font-size', '\(clamped)px');"
    }

    public static func lineHeightScript(value: Double) -> String {
        let clamped = min(2.4, max(1.2, value))
        let formatted = String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), clamped)
        return "document.documentElement.style.setProperty('--monori-line-height', '\(formatted)');"
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
          @font-face {
            font-family: "Source Serif 4";
            src: local("SourceSerif4Variable-Roman"), local("Source Serif 4");
            font-weight: 200 900;
            font-display: swap;
          }
          @font-face {
            font-family: "Noto Serif TC";
            src: local("NotoSerifTC-Regular"), local("Noto Serif TC");
            font-weight: 200 900;
            font-display: swap;
          }
          :root { color-scheme: light dark; --monori-font-size: \(size)px; --monori-line-height: \(lh); }
          html, body { background: #FBF9F8; }
          body { margin: 0; padding: 1em clamp(24px, 6vw, 48px); color: #1C1B19;
                 font-family: "Source Serif 4", "Noto Serif TC", serif;
                 word-break: break-word; max-width: 34em; margin-left: auto; margin-right: auto; }
          /* Google Docs mobilebasic exports inline color:#000000 and
             background-color:#ffffff on every paragraph and span.
             Override them so the page adapts to light/dark mode. */
          body * { color: inherit !important; background-color: transparent !important; }
          html, body { background: #FBF9F8 !important; }
          @media (prefers-color-scheme: dark) {
            html, body { background: #1C1B19 !important; }
            body { color: #F2F0ED !important; }
          }
          /* Resize prose and everything inside it, but NOT <h1>-<h6> or their
             children, so chapter sub-headings keep their relative size. A bare
             `body span` rule would flatten Google headings, whose text is
             wrapped in <span> (<h2><span style="font-size:12pt">…). */
          body,
          body p, body p *,
          body li, body li *,
          body blockquote, body blockquote *,
          body td, body td * {
            font-size: var(--monori-font-size) !important;
            line-height: var(--monori-line-height) !important;
          }
          body p { margin-bottom: 0.85em; }
          img { max-width: 100%; height: auto; }
          blockquote { border-left: 3px solid rgba(128,128,128,0.3);
                       margin: 1em 0; padding: 0.5em 1em; }
          hr { border: none; border-top: 1px solid rgba(128,128,128,0.3); margin: 2em 0; }
        </style></head><body>\(inner)</body></html>
        """
    }

    /// Captures the current scroll progress as a value in [0, 1], or null if the
    /// page is too short to scroll.
    public static let captureScrollProgressScript = """
    (function () {
      var doc = document.documentElement;
      var max = doc.scrollHeight - window.innerHeight;
      if (max <= 0) { return null; }
      var progress = window.scrollY / max;
      return Math.min(1, Math.max(0, progress));
    })();
    """

    /// Pins the scroll position to `progress` (or top when nil) for a few seconds,
    /// re-applying every 400ms to defeat Patreon's own auto-scroll. Stops as soon
    /// as the user touches or wheel-scrolls the page.
    public static func enforceScrollScript(progress: Double?) -> String {
        let target = progress.map { min(1.0, max(0.0, $0)) } ?? 0.0
        return """
        (function () {
          var target = \(target);
          var until = Date.now() + 4000;
          if (!window.__monoriInteractionHook) {
            window.__monoriInteractionHook = true;
            var mark = function () { window.__monoriUserInteracted = true; };
            window.addEventListener("touchstart", mark, { passive: true });
            window.addEventListener("wheel", mark, { passive: true });
          }
          window.__monoriUserInteracted = false;
          if (window.__monoriScrollEnforcer) {
            clearInterval(window.__monoriScrollEnforcer);
          }
          function apply() {
            var doc = document.documentElement;
            var max = doc.scrollHeight - window.innerHeight;
            window.scrollTo(0, max > 0 ? max * target : 0);
          }
          apply();
          window.__monoriScrollEnforcer = setInterval(function () {
            if (window.__monoriUserInteracted === true || Date.now() > until) {
              clearInterval(window.__monoriScrollEnforcer);
              window.__monoriScrollEnforcer = null;
              return;
            }
            apply();
          }, 400);
        })();
        """
    }
}
