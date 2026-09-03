import Foundation

public enum ReaderStyler {
    public static let styleElementID = "monori-reader-style"
    public static let userFontStyleID = "monori-user-font-style"
    public static let iPadLayoutStyleID = "monori-ipad-reader-layout"
    static let defaultFontStack = #""Source Serif 4", "Noto Serif TC", serif"#

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

    /// Expands the reading surface on regular-width iPad layouts without
    /// changing the phone rulesets. Live Patreon/AO3 pages are reduced to their
    /// prose plus comments; imported HTML and the other source-specific readers
    /// retain their existing cleanup and only receive the width override.
    public static func iPadReaderLayoutScript() -> String {
        """
        (function () {
          function applyIPadReaderLayout() {
            var old = document.getElementById("\(iPadLayoutStyleID)");
            if (old) old.remove();
            var style = document.createElement('style');
            style.id = "\(iPadLayoutStyleID)";
            style.textContent = `
              html, body {
                width: 100% !important;
                max-width: none !important;
                box-sizing: border-box !important;
              }
              [data-tag="post-content"], .patreon-post-content,
              .userstuff[role="article"], #chapters .userstuff,
              .editor-content-block, .lexical-web-theme,
              #bodyText, #comments {
                width: 100% !important;
                max-width: none !important;
                box-sizing: border-box !important;
              }
              [data-tag="post-content"], [data-tag="post-content"] *,
              .patreon-post-content, .patreon-post-content *,
              .userstuff[role="article"], .userstuff[role="article"] *,
              #chapters .userstuff, #chapters .userstuff *,
              .editor-content-block, .editor-content-block *,
              .lexical-web-theme, .lexical-web-theme *,
              #bodyText, #bodyText * {
                font-family: var(--monori-font-family) !important;
              }
              [data-tag="post-content"] :is(div, section, article, main, p, li, blockquote),
              .patreon-post-content :is(div, section, article, main, p, li, blockquote),
              .userstuff[role="article"] :is(div, section, article, main, p, li, blockquote),
              #chapters .userstuff :is(div, section, article, main, p, li, blockquote),
              .editor-content-block :is(div, section, article, main, p, li, blockquote),
              .lexical-web-theme :is(div, section, article, main, p, li, blockquote),
              #bodyText :is(div, section, article, main, p, li, blockquote) {
                width: auto !important;
                max-width: none !important;
              }
              [data-tag="content-card-comment-thread-container"],
              #comments, #comments_placeholder, #feedback {
                width: 100% !important;
                max-width: none !important;
                box-sizing: border-box !important;
                padding-left: 32px !important;
                padding-right: 32px !important;
              }
            `;
            document.documentElement.appendChild(style);

            var liveSelector = [
              '[data-tag="post-content"]',
              '.patreon-post-content',
              '.userstuff[role="article"]',
              '#chapters .userstuff'
            ].join(',');
            var content = document.querySelector(liveSelector) ||
                          document.querySelector('.editor-content-block') ||
                          document.querySelector('.lexical-web-theme') ||
                          document.querySelector('#bodyText');
            var readingSurface = content || document.body;

            document.body.style.setProperty('width', '100%', 'important');
            document.body.style.setProperty('max-width', 'none', 'important');
            document.body.style.setProperty('box-sizing', 'border-box', 'important');
            document.body.style.setProperty('padding-left', content ? '0' : '32px', 'important');
            document.body.style.setProperty('padding-right', content ? '0' : '32px', 'important');
            document.body.style.setProperty('margin-left', '0', 'important');
            document.body.style.setProperty('margin-right', '0', 'important');

            readingSurface.style.setProperty('width', '100%', 'important');
            readingSurface.style.setProperty('max-width', 'none', 'important');
            readingSurface.style.setProperty('box-sizing', 'border-box', 'important');
            readingSurface.style.setProperty('padding-left', '32px', 'important');
            readingSurface.style.setProperty('padding-right', '32px', 'important');
            readingSurface.style.setProperty('margin-left', '0', 'important');
            readingSurface.style.setProperty('margin-right', '0', 'important');

            if (content) {
              var shouldIsolate = content.matches(liveSelector);
              var commentsSelector = [
                  '[data-tag="content-card-comment-thread-container"]',
                  '#comments', '#comments_placeholder', '#feedback'
                ].join(',');
              var cursor = content;
              while (cursor && cursor.parentElement &&
                     cursor.parentElement !== document.documentElement) {
                var parent = cursor.parentElement;
                parent.style.setProperty('width', '100%', 'important');
                parent.style.setProperty('max-width', 'none', 'important');
                parent.style.setProperty('box-sizing', 'border-box', 'important');
                parent.style.setProperty('padding-left', '0', 'important');
                parent.style.setProperty('padding-right', '0', 'important');
                parent.style.setProperty('margin-left', '0', 'important');
                parent.style.setProperty('margin-right', '0', 'important');
                parent.style.setProperty('background-color', 'transparent', 'important');
                var pd = window.getComputedStyle(parent).display;
                if (pd === 'grid' || pd === 'inline-grid') {
                  parent.style.setProperty('grid-template-columns', '1fr', 'important');
                } else if (pd === 'flex' || pd === 'inline-flex') {
                  parent.style.setProperty('flex-direction', 'column', 'important');
                }
                if (shouldIsolate) {
                  for (var i = 0; i < parent.children.length; i++) {
                    var sibling = parent.children[i];
                    if (sibling === cursor ||
                        sibling.tagName === 'STYLE' || sibling.tagName === 'SCRIPT' ||
                        sibling.tagName === 'LINK' ||
                        sibling.matches(commentsSelector) || sibling.querySelector(commentsSelector)) {
                      continue;
                    }
                    sibling.style.setProperty('display', 'none', 'important');
                  }
                }
                cursor = parent;
              }
            }
          }
          applyIPadReaderLayout();
          setTimeout(applyIPadReaderLayout, 500);
          setTimeout(applyIPadReaderLayout, 1500);
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
          var uf = document.getElementById("\(userFontStyleID)");
          if (uf) { uf.remove(); }
          document.documentElement.style.removeProperty('--monori-font-family');
        })();
        """
    }

    public static func fontSizeScript(points: Int) -> String {
        let clamped = min(48, max(14, points))
        return "document.documentElement.style.setProperty('--monori-font-size', '\(clamped)px');"
    }

    public static func lineHeightScript(value: Double) -> String {
        let clamped = min(2.4, max(1.2, value))
        let formatted = String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), clamped)
        return "document.documentElement.style.setProperty('--monori-line-height', '\(formatted)');"
    }

    /// Re-applies font-size and line-height CSS variables after delays,
    /// working around a timing race on iPad where Patreon SPA rendering
    /// resets the inline custom-property values set by applyCurrentPreferences.
    public static func iPadDelayedPrefsScript(fontSize: Int, lineSpacing: Double) -> String {
        let clampedSize = min(48, max(14, fontSize))
        let clampedSpacing = min(2.4, max(1.2, lineSpacing))
        let formatted = String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), clampedSpacing)
        return """
        (function(){
          var s='\(clampedSize)px',h='\(formatted)';
          function r(){
            document.documentElement.style.setProperty('--monori-font-size',s);
            document.documentElement.style.setProperty('--monori-line-height',h);
          }
          setTimeout(r,600);
          setTimeout(r,1600);
        })();
        """
    }

    public static func fontFamilyScript(font: ReaderFontCSS) -> String {
        switch font {
        case .builtIn:
            return """
            (function () {
              var old = document.getElementById("\(userFontStyleID)");
              if (old) { old.remove(); }
              document.documentElement.style.setProperty('--monori-font-family',
                '\(defaultFontStack)');
            })();
            """
        case .embeddedDataURL(let mimeType, let base64):
            return """
            (function () {
              var old = document.getElementById("\(userFontStyleID)");
              if (old) { old.remove(); }
              var style = document.createElement("style");
              style.id = "\(userFontStyleID)";
              style.textContent = '@font-face { font-family: "MonoriUserFont"; ' +
                'src: url("data:\(mimeType);base64,\(base64)"); ' +
                'font-display: swap; }';
              document.documentElement.appendChild(style);
              document.documentElement.style.setProperty('--monori-font-family',
                '"MonoriUserFont", "Noto Serif TC", serif');
              document.fonts.load('16px "MonoriUserFont"').then(function () {
                return "ok";
              }).catch(function () {
                var bad = document.getElementById("\(userFontStyleID)");
                if (bad) { bad.remove(); }
                document.documentElement.style.setProperty('--monori-font-family',
                  '\(defaultFontStack)');
                return "fallback";
              });
            })();
            """
        }
    }

    public static func chineseConversionScript(mode: ChineseConversion, mapString: String) -> String {
        let modeStr = mode.rawValue
        return """
        (function(){
          if(!window.__monoriConv)window.__monoriConv=new WeakMap();
          var s=window.__monoriConv;
          var w=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT);
          var n;
          while(n=w.nextNode()){var o=s.get(n);if(o!==undefined)n.nodeValue=o;}
          if('\(modeStr)'==='off')return;
          var m={},p='\(mapString)';
          for(var i=0;i<p.length;i+=2)m[p[i]]=p[i+1];
          var w2=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT);
          while(n=w2.nextNode()){
            var t=n.nodeValue,r='',c=false;
            for(var j=0;j<t.length;j++){var x=m[t[j]];if(x){r+=x;c=true;}else r+=t[j];}
            if(c){s.set(n,t);n.nodeValue=r;}
          }
        })();
        """
    }

    /// Full HTML document wrapper for stored chapter HTML (Google Docs import).
    /// Google Docs export inline `font-size`/`line-height` on every paragraph and
    /// span, which beats a plain `body` rule — so the reader's prefs never reach
    /// the prose. The descendant rules below use `!important` so the CSS
    /// variables (also updated live by `fontSizeScript`/`lineHeightScript`) win
    /// over Google's inline styles. Headings keep their own size for hierarchy.
    public static func wrappedDocument(inner: String, fontSizePoints: Int, lineHeight: Double,
                                       font: ReaderFontCSS = .builtIn) -> String {
        let size = min(48, max(14, fontSizePoints))
        let lh = String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"),
                        min(2.4, max(1.2, lineHeight)))
        let userFontFace: String
        let fontFamilyValue: String
        switch font {
        case .builtIn:
            userFontFace = ""
            fontFamilyValue = defaultFontStack
        case .embeddedDataURL(let mimeType, let base64):
            userFontFace = """
              @font-face {
                font-family: "MonoriUserFont";
                src: url("data:\(mimeType);base64,\(base64)");
                font-display: swap;
              }
            """
            fontFamilyValue = #""MonoriUserFont", "Noto Serif TC", serif"#
        }
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
        \(userFontFace)
          :root { color-scheme: light dark;
                  --monori-font-family: \(fontFamilyValue);
                  --monori-font-size: \(size)px; --monori-line-height: \(lh); }
          html, body { background: #FBF9F8; }
          body { margin: 0; padding: 1em clamp(24px, 6vw, 48px); color: #1C1B19;
                 font-family: var(--monori-font-family);
                 word-break: break-word; max-width: 34em; margin-left: auto; margin-right: auto; }
          body * { color: inherit !important; background-color: transparent !important; }
          html, body { background: #FBF9F8 !important; }
          @media (prefers-color-scheme: dark) {
            html, body { background: #1C1B19 !important; }
            body { color: #F2F0ED !important; }
          }
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
