"use strict";
// Collects the chapter list from a CXC work page's "章節列表" tab and returns
// it as a plain array via callAsyncJavaScript's top-level `return`, matching
// VocusRoomImport.js / AFFStoryImport.js rather than the JSON.stringify(...)
// wrapper style -- nothing in this codebase evaluates a JS asset and parses a
// stringified result out of it.
//
// DOM selectors are generic placeholders pending real DevTools inspection of
// cxc.today (see CXCWorkDetect.js); refine them once the real markup is
// confirmed. No SPA scroll/pagination handling yet -- the task brief's own
// reference script is a single synchronous scan, so this keeps that scope
// until the real tab/list behavior is known. Re-detecting after SPA
// navigation (MutationObserver / URL-change hook) is a WebViewModel-side
// concern per the Vocus precedent (commit 931ac57), not something this
// injected script needs to own.

function compactText(value) {
  return (value || '').replace(/\s+/g, ' ').trim();
}

function currentWork() {
  var path = location.pathname.replace(/^\/(zh|en|jp|ko)\//, '/');
  var match = path.match(/^\/@([^/]+)\/work\/(\d+)/);
  return match ? { username: match[1], workId: match[2] } : null;
}

var work = currentWork();

var titleEl = document.querySelector('h1, [class*="title"]');
var authorEl = document.querySelector('[class*="author"], [class*="creator"]');

var workTitle = compactText(titleEl ? titleEl.textContent : document.title);
var authorName = authorEl ? compactText(authorEl.textContent) : (work ? work.username : '');
var workURL = work
  ? ('https://cxc.today/zh/@' + work.username + '/work/' + work.workId)
  : location.href;

var items = document.querySelectorAll('[class*="chapter"], [class*="episode"]');
var chapters = [];
items.forEach(function (item, index) {
  var link = item.querySelector('a') || item.closest('a');
  if (!link) return;
  var titleNode = item.querySelector('[class*="title"]');
  chapters.push({
    title: titleNode ? compactText(titleNode.textContent) : ('Chapter ' + (index + 1)),
    url: link.href,
    // Recomputed from the accepted count, not the raw NodeList index, so a
    // skipped no-link item (e.g. a "章節列表" section heading matching the
    // same broad class selector) never leaves a gap in the ordering -- same
    // fix as VocusRoomImport.js's `domOrder: collected.length`.
    domOrder: chapters.length,
    isFree: item.textContent.indexOf('免費') !== -1,
    creatorName: authorName || null,
    collectionName: workTitle,
    collectionURL: workURL
  });
});

return chapters;
