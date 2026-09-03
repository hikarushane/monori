"use strict";
// Collects the chapter list from a CXC work/book page and returns it as a
// plain array via callAsyncJavaScript. CXC uses /work/ for novels and /book/
// for comics. Chapter links use /@{user}/{work|book}/{id}/reader/{readerId}.

function compactText(value) {
  return (value || '').replace(/\s+/g, ' ').trim();
}

function currentWork() {
  var path = location.pathname.replace(/^\/(zh|en|jp|ko)\//, '/');
  var match = path.match(/^\/@([^/]+)\/(work|book)\/(\d+)/);
  return match ? { username: match[1], contentType: match[2], workId: match[3] } : null;
}

var work = currentWork();

// document.title format: "作品名 | 作者顯示名"
var parts = document.title.split(' | ');
var workTitle = compactText(parts[0]) || compactText(document.title);
if (!workTitle) {
  var nameEl = document.querySelector('.book_header .name');
  workTitle = nameEl ? compactText(nameEl.textContent) : '';
}

var authorName = compactText(parts[1]);
if (!authorName) {
  var storeEl = document.querySelector('a.store_name');
  authorName = storeEl ? compactText(storeEl.textContent) : '';
}
if (!authorName && work) authorName = work.username;

var workURL = work
  ? ('https://cxc.today/@' + work.username + '/' + work.contentType + '/' + work.workId)
  : location.href;

// Chapter links live under .section-list__item__section and point to /reader/
var items = document.querySelectorAll('.section-list__item__section a[href*="/reader/"]');
var chapters = [];
items.forEach(function (item) {
  var titleNode = item.querySelector('.info__name');
  var chapterTitle = titleNode ? compactText(titleNode.textContent) : ('Chapter ' + (chapters.length + 1));
  // Canonicalize URL: strip language prefix to match what URLNormalizer produces
  var href = item.getAttribute('href') || '';
  var cleanHref = href.replace(/^\/(zh|en|jp|ko)\//, '/');
  var fullURL = 'https://cxc.today' + cleanHref;
  chapters.push({
    title: chapterTitle,
    url: fullURL,
    domOrder: chapters.length,
    creatorName: authorName || null,
    collectionName: workTitle,
    collectionURL: workURL
  });
});

return chapters;
