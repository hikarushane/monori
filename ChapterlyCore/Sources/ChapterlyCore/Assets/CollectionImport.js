(function () {
  "use strict";
  var handler = window.webkit && window.webkit.messageHandlers
    && window.webkit.messageHandlers.chapterlyImport;
  if (!handler) { return; }

  function limitField(value) {
    return compactText(value).slice(0, 256);
  }

  var h1 = document.querySelector("h1");
  var collectionName = limitField((h1 && h1.textContent) || document.title || "");
  var collectionURL = location.href;
  var creatorName = creatorNameFromPage();

  function compactText(value) {
    return (value || "").replace(/\s+/g, " ").trim();
  }

  function slugTitle(href) {
    try {
      var parts = new URL(href).pathname.split("/").filter(Boolean);
      var slug = parts.length ? parts[parts.length - 1] : "";
      slug = slug.replace(/-?\d{6,}$/, "");
      return compactText(decodeURIComponent(slug).replace(/[-_]+/g, " "));
    } catch (e) {
      return "";
    }
  }

  function titleCandidate(value) {
    var text = limitField(value);
    if (!text || text.length > 180) { return ""; }
    return text;
  }

  function firstMatchingText(root, selector) {
    var nodes = [];
    if (root.matches && root.matches(selector)) {
      nodes.push(root);
    }
    var found = root.querySelectorAll ? root.querySelectorAll(selector) : [];
    for (var i = 0; i < found.length; i++) {
      nodes.push(found[i]);
    }
    for (var j = 0; j < nodes.length; j++) {
      var candidate = titleCandidate(nodes[j].textContent);
      if (candidate) { return candidate; }
    }
    return "";
  }

  function titleFromCard(anchor) {
    var selectors = [
      '[data-tag="post-title"]',
      '[data-testid="post-title"]',
      'h1',
      'h2',
      'h3',
      '[class*="title"]',
      '[class*="Title"]'
    ];
    for (var i = 0; i < selectors.length; i++) {
      var candidate = firstMatchingText(anchor, selectors[i]);
      if (candidate) { return candidate; }
    }
    return "";
  }

  function titleFromShortAnchorText(anchor) {
    var raw = anchor.textContent || "";
    var lines = raw.split(/\n+/).map(compactText).filter(Boolean);
    if (lines.length === 1) { return titleCandidate(lines[0]); }
    return "";
  }

  function titleForAnchor(anchor, href) {
    return titleFromCard(anchor)
      || limitField(anchor.getAttribute("aria-label"))
      || limitField(anchor.getAttribute("title"))
      || titleFromShortAnchorText(anchor)
      || slugTitle(href)
      || "Patreon post";
  }

  function creatorNameFromPage() {
    var meta = document.querySelector('meta[name="author"], meta[property="article:author"]');
    var fromMeta = meta && meta.getAttribute("content");
    if (fromMeta) { return limitField(fromMeta); }

    var title = document.title || "";
    var match = title.match(/\|\s*Collection from\s+(.+?)\s*\|/i);
    if (match && match[1]) { return limitField(match[1]); }

    var creatorLink = document.querySelector('a[href^="/cw/"], a[href^="/m/"]');
    return limitField(creatorLink && creatorLink.textContent);
  }

  var seen = {};
  var order = 0;
  var anchors = document.querySelectorAll('a[href*="/posts/"]');
  for (var i = 0; i < anchors.length; i++) {
    var a = anchors[i];
    var href = a.href || "";
    if (!href || seen[href]) { continue; }
    var title = titleForAnchor(a, href);
    if (!title) { continue; }
    seen[href] = true;
    handler.postMessage({
      title: title,
      url: href,
      visibleDateText: null,
      creatorName: creatorName || null,
      collectionName: collectionName,
      collectionURL: collectionURL,
      domOrder: order
    });
    order += 1;
  }
})();
