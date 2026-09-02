(function () {
  // Detects a CXC work page and posts its metadata to the monoriCollectionLink
  // handler, matching the Vocus/AFF/AO3 detect scripts' contract so the app
  // can show the "Import chapters" banner (see VocusRoomDetect.js,
  // AFFStoryDetect.js, AO3WorkDetect.js). URL shape confirmed by
  // URLNormalizer's CXC parsing: /{lang}/@{username}/work/{workId}, where
  // {lang} is one of zh/en/jp/ko and may be absent.
  if (location.hostname !== 'cxc.today' && !location.hostname.endsWith('.cxc.today')) return;

  var path = location.pathname.replace(/^\/(zh|en|jp|ko)\//, '/');
  var match = path.match(/^\/@([^/]+)\/work\/(\d+)/);
  if (!match) return;

  var handler = window.webkit && window.webkit.messageHandlers
    && window.webkit.messageHandlers.monoriCollectionLink;
  if (!handler) return;

  var username = match[1];
  var workId = match[2];

  // DOM selectors are generic placeholders pending real DevTools inspection
  // of cxc.today; refine them once the real markup is confirmed.
  var titleEl = document.querySelector('h1, [class*="title"]');
  var authorEl = document.querySelector('[class*="author"], [class*="creator"]');

  var title = titleEl ? titleEl.textContent.trim() : document.title;
  var author = authorEl ? authorEl.textContent.trim() : username;

  handler.postMessage({
    collectionName: title,
    collectionURL: 'https://cxc.today/zh/@' + username + '/work/' + workId,
    creatorName: author
  });
})();
