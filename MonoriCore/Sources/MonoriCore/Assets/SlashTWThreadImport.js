"use strict";
// Collects the per-floor "chapter" list from a slashtw (在水裡寫字) thread page
// and returns it as a plain array via callAsyncJavaScript's top-level
// `return`, matching CXCWorkImport.js / VocusRoomImport.js / AFFStoryImport.js
// rather than the JSON.stringify(...) wrapper style -- nothing in this
// codebase evaluates a JS asset and parses a stringified result out of it.
//
// Chapter-splitting model (task-12 brief, selectors TBD pending DevTools):
// slashtw threads are Discuz-style forum threads migrating to the Waterfall
// platform. The assumed model -- unverified against the live site, which
// requires a logged-in session to view at all -- is that EVERY floor (post)
// in the thread, including the opening post, is one chapter, in DOM order.
// This does not yet distinguish the thread author's own update posts from
// other users' replies/quotes landing in the same thread; refine once real
// markup and the forum's actual chaptering convention are confirmed (see the
// brief's open question: one long post split by dividers, vs. one post per
// chapter with the first post as the opening chapter).
//
// DOM selectors are generic `[class*="..."]` placeholders. Of the task's
// four suggested keywords (post/thread/reply/floor), a bare [class*="thread"]
// is deliberately left OUT of the per-floor selector below: it is far more
// likely to match the page-level thread container (e.g. a "thread-wrapper"
// div around every floor) than an individual floor, which would add one
// giant bogus extra "chapter" spanning the whole page. "thread" is only used
// for URL parsing (see currentThread() below), matching
// URLNormalizer.slashtwThreadID's own path-segment check.
//
// No SPA scroll/pagination handling yet -- like CXCWorkImport.js, this stays
// a single synchronous scan of whatever floors are already in the DOM until
// the real multi-page-thread behavior is known.

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

var threadId = currentThread();

var titleEl = document.querySelector('h1, [class*="title"], [class*="subject"]');
var authorEl = document.querySelector('[class*="author"], [class*="username"], [class*="poster"]');

var threadTitle = compactText(titleEl ? titleEl.textContent : document.title);
var authorName = authorEl ? compactText(authorEl.textContent) : null;
var threadURL = threadId
  ? ('https://waterfall.slashtw.space/thread/' + threadId)
  : location.href;

// TODO: verify with DevTools -- floor/post selector and per-floor permalink
// shape are both placeholders pending real Waterfall markup.
var items = document.querySelectorAll('[class*="post"], [class*="reply"], [class*="floor"]');
var chapters = [];
items.forEach(function (item, index) {
  var link = item.querySelector('a[href]') || item.closest('a[href]');
  if (!link) return;

  // The floor-number badge is a separate, narrower selector than the row
  // selector above on purpose: it must NOT itself contain "post"/"reply"/
  // "floor" (e.g. a class like "floor-num") or it would also match the row
  // query above and be double-counted as its own bogus extra chapter.
  var floorLabelEl = item.querySelector('[class*="index"]');
  var floorLabel = floorLabelEl
    ? compactText(floorLabelEl.textContent)
    : ('第 ' + (chapters.length + 1) + ' 樓');

  chapters.push({
    title: floorLabel,
    url: link.href,
    // Recomputed from the accepted count, not the raw NodeList index, so a
    // skipped no-link item (a list heading, a moderator note, or the OP-name
    // badge -- "poster" itself contains the substring "post") never leaves a
    // gap in the ordering -- same fix as CXCWorkImport.js's
    // `domOrder: chapters.length`.
    domOrder: chapters.length,
    creatorName: authorName,
    collectionName: threadTitle,
    collectionURL: threadURL
  });
});

return chapters;
