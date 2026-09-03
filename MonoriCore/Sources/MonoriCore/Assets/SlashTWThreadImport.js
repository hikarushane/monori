"use strict";
// Collects the per-floor "chapter" list from a slashtw (在水裡寫字 / Waterfall)
// thread page. Each .card-post.thread element is one floor (chapter).
//
// Waterfall renders floors via infinite scroll — only the first ~5 are in the
// DOM initially. Before collecting, scroll to the bottom repeatedly to trigger
// lazy loading of all floors.
//
// Every floor also carries its body as `contentHTML`. All floors share the
// thread URL (only the #post fragment differs), so the reader cannot load a
// single chapter by URL — it renders the stored body instead (ADR-0012, 2026-09
// revision). The body is the div.content block(s) inside .card-content; the
// thread-title block (.title), heading row (.subtitle) and the .comments
// interaction block are left out. See floorBodyHTML for the fallback.

function compactText(value) {
  return (value || '').replace(/\s+/g, ' ').trim();
}

function currentThread() {
  var segments = location.pathname.split('/').filter(Boolean);
  var threadIdx = segments.indexOf('thread');
  if (threadIdx !== -1 && threadIdx + 1 < segments.length && /^\d+$/.test(segments[threadIdx + 1])) {
    return segments[threadIdx + 1];
  }
  if (segments.length === 1 && segments[0] === 'forum.php') {
    var params = new URLSearchParams(location.search);
    if (params.get('mod') === 'viewthread') {
      var tid = params.get('tid');
      if (tid && /^\d+$/.test(tid)) return tid;
    }
  }
  return null;
}

// Body HTML of one floor, or null when the floor has no readable body.
//
// Waterfall's .card-content (verified 2026-09-03 from markup captured in the
// app's own WebView) holds, in order: .title (thread title, 1F only),
// .subtitle (chapter heading + floor link), one or more div.content (the post
// body — the second one is usually empty), and div.comments (comment thread,
// login prompt, reaction/feed widgets). The body is the .content blocks,
// unwrapped. When no .content child exists (markup change), fall back to
// everything except the known chrome blocks. Direct children only — a post
// body may legitimately contain elements with these class names deeper down.
function floorBodyHTML(floor) {
  var content = floor.querySelector('.card-content');
  if (!content) return null;
  var children = Array.prototype.slice.call(content.children);
  var bodies = children.filter(function (c) { return c.classList.contains('content'); });
  var root = document.createElement('div');
  if (bodies.length) {
    bodies.forEach(function (b) {
      Array.prototype.slice.call(b.cloneNode(true).childNodes).forEach(function (n) {
        root.appendChild(n);
      });
    });
  } else {
    children.forEach(function (c) {
      if (c.classList.contains('title') || c.classList.contains('subtitle')
          || c.classList.contains('comments')) return;
      root.appendChild(c.cloneNode(true));
    });
  }
  // script/style/iframe are dropped here as defense in depth (HTMLSanitizer
  // runs again on the Swift side). i.pstatus is Discuz's "last edited by"
  // stamp — platform metadata, not prose.
  root.querySelectorAll('script, style, iframe, object, embed, i.pstatus').forEach(function (el) {
    el.remove();
  });
  var html = root.innerHTML.trim();
  if (!html) return null;
  if (!root.textContent.trim() && !root.querySelector('img')) return null;
  return html;
}

var threadId = currentThread();

// Thread title: h1 > a.title-link, fallback to document.title minus suffix.
var h1 = document.querySelector('h1');
var threadTitle = h1 ? compactText(h1.textContent) : null;
if (!threadTitle) {
  threadTitle = document.title.replace(/\s*-\s*在水裡寫字\s*$/, '').trim();
}

// Thread-level author from the first floor's author-info.
var firstAuthorLink = document.querySelector('.card-post.thread .author-info a[href*="/user/"]');
var threadAuthor = firstAuthorLink ? compactText(firstAuthorLink.textContent) : null;

var threadURL = threadId
  ? ('https://waterfall.slashtw.space/thread/' + threadId)
  : location.href;

// Scroll to the bottom repeatedly to load all lazy-loaded floors.
var _prevFloorCount = 0;
var _prevHeight = 0;
for (var _i = 0; _i < 30; _i++) {
  window.scrollTo(0, document.body.scrollHeight);
  await new Promise(function (r) { setTimeout(r, 400); });
  var _curFloors = document.querySelectorAll('.card-post.thread').length;
  var _curHeight = document.body.scrollHeight;
  if (_curFloors === _prevFloorCount && _curHeight === _prevHeight) break;
  _prevFloorCount = _curFloors;
  _prevHeight = _curHeight;
}
window.scrollTo(0, 0);
await new Promise(function (r) { setTimeout(r, 200); });

// Each .card-post.thread is one floor (chapter). The bare .card-post without
// .thread is either the login overlay or a footer element — skip those.
var floors = document.querySelectorAll('.card-post.thread');
var chapters = [];
floors.forEach(function (floor) {
  // Chapter title from h2 > a.title-link inside .subtitle
  var titleLink = floor.querySelector('.subtitle h2 a.title-link');
  if (!titleLink) return;

  var chapterTitle = compactText(titleLink.textContent);
  var chapterURL = titleLink.href;

  // Floor number from a.floor-link (text "1F", "2F", etc.)
  var floorLink = floor.querySelector('a.floor-link');
  var floorLabel = floorLink ? compactText(floorLink.textContent) : null;

  // Per-floor author (usually same as thread author for serials)
  var authorLink = floor.querySelector('.author-info a[href*="/user/"]');
  var floorAuthor = authorLink ? compactText(authorLink.textContent) : threadAuthor;

  chapters.push({
    title: chapterTitle || floorLabel || ('第 ' + (chapters.length + 1) + ' 樓'),
    url: chapterURL,
    contentHTML: floorBodyHTML(floor),
    domOrder: chapters.length,
    creatorName: floorAuthor,
    collectionName: threadTitle,
    collectionURL: threadURL
  });
});

return chapters;
