"use strict";
// Runs as the body of an async function (WKWebView callAsyncJavaScript), so
// top-level `await` and `return` are available. Returns the number of
// chapters posted to the native side.
var handler = window.webkit && window.webkit.messageHandlers
  && window.webkit.messageHandlers.chapterlyImport;
if (!handler) { return 0; }

function compactText(value) {
  return (value || "").replace(/\s+/g, " ").trim();
}

function limitField(value) {
  return compactText(value).slice(0, 256);
}

var h1 = document.querySelector("h1");
var collectionName = limitField((h1 && h1.textContent) || document.title || "");
var collectionURL = location.href;
var creatorName = creatorNameFromPage();

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

function excerptWithin(root, title) {
  var selectors = [
    '[data-tag*="teaser"]',
    '[class*="teaser"]',
    '[class*="excerpt"]',
    '[class*="Excerpt"]',
    '[class*="snippet"]',
    'p'
  ];
  for (var i = 0; i < selectors.length; i++) {
    var nodes = root.querySelectorAll ? root.querySelectorAll(selectors[i]) : [];
    for (var j = 0; j < nodes.length; j++) {
      var text = compactText(nodes[j].textContent);
      if (!text || text === title) { continue; }
      if (text.length >= 10 && text.length <= 300) { return text; }
    }
  }
  return "";
}

function excerptFromAnchorText(anchor, title) {
  var raw = anchor.textContent || "";
  var lines = raw.split(/\n+/).map(compactText).filter(Boolean);
  var rest = [];
  for (var i = 0; i < lines.length; i++) {
    if (lines[i] === title) { continue; }
    rest.push(lines[i]);
  }
  var joined = compactText(rest.join(" "));
  return joined.length >= 10 ? joined : "";
}

function distinctPostLinkCount(node) {
  var anchors = node.querySelectorAll ? node.querySelectorAll('a[href*="/posts/"]') : [];
  var seenHrefs = {};
  var count = 0;
  for (var i = 0; i < anchors.length; i++) {
    var href = anchors[i].href || "";
    if (!href || seenHrefs[href]) { continue; }
    seenHrefs[href] = true;
    count += 1;
  }
  return count;
}

function excerptFromCard(anchor, title) {
  // 1. Teaser inside the anchor itself.
  var inside = excerptWithin(anchor, title);
  if (inside) { return inside.slice(0, 256); }
  // 2. Anchor text has title + teaser on separate lines.
  var fromText = excerptFromAnchorText(anchor, title);
  if (fromText) { return fromText.slice(0, 256); }
  // 3. Teaser is a sibling: climb to the card container, but never past
  //    a node that spans more than one distinct post link.
  var node = anchor.parentElement;
  for (var depth = 0; node && depth < 4; depth++) {
    if (distinctPostLinkCount(node) > 1) { break; }
    var found = excerptWithin(node, title);
    if (found) { return found.slice(0, 256); }
    node = node.parentElement;
  }
  return null;
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

function sleep(ms) {
  return new Promise(function (resolve) { setTimeout(resolve, ms); });
}

function clickLoadMoreIfAny() {
  var buttons = document.querySelectorAll("button");
  for (var i = 0; i < buttons.length; i++) {
    var label = compactText(buttons[i].textContent).toLowerCase();
    if (/^(load|show|view)\s+more/.test(label)) { buttons[i].click(); return; }
  }
}

var seen = {};
var collected = [];

// Capture cards as they appear; some lists virtualize and drop earlier rows
// from the DOM, so each pass only adds links never seen before. domOrder is
// first-seen order, which matches top-to-bottom DOM order on Patreon.
function collectVisible() {
  var anchors = document.querySelectorAll('a[href*="/posts/"]');
  for (var i = 0; i < anchors.length; i++) {
    var a = anchors[i];
    var href = a.href || "";
    if (!href || seen[href]) { continue; }
    var title = titleForAnchor(a, href);
    if (!title) { continue; }
    seen[href] = true;
    collected.push({
      title: title,
      url: href,
      visibleDateText: null,
      excerpt: excerptFromCard(a, title),
      creatorName: creatorName || null,
      collectionName: collectionName,
      collectionURL: collectionURL,
      domOrder: collected.length
    });
  }
}

// Patreon loads the collection list lazily. Scroll (and click any
// "load more" button) until the set of post links stops growing, so the
// import covers every chapter, not just the cards already rendered.
var previousCount = -1;
var stableRounds = 0;
for (var round = 0; round < 60 && stableRounds < 3; round++) {
  collectVisible();
  clickLoadMoreIfAny();
  window.scrollTo(0, document.documentElement.scrollHeight);
  await sleep(500);
  var count = document.querySelectorAll('a[href*="/posts/"]').length;
  if (count === previousCount) {
    stableRounds += 1;
  } else {
    stableRounds = 0;
    previousCount = count;
  }
}
collectVisible();
window.scrollTo(0, 0);

for (var p = 0; p < collected.length; p++) {
  handler.postMessage(collected[p]);
}
return collected.length;
