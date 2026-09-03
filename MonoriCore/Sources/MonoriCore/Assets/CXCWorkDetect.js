(function () {
  // Detects a CXC work/book page and posts its metadata to the
  // monoriCollectionLink handler. CXC is a SPA — document.title may be
  // empty at injection time, so we poll until it appears (up to 5 s).
  if (location.hostname !== 'cxc.today' && !location.hostname.endsWith('.cxc.today')) return;

  var path = location.pathname.replace(/^\/(zh|en|jp|ko)\//, '/');
  var match = path.match(/^\/@([^/]+)\/(work|book)\/(\d+)/);
  if (!match) return;

  var handler = window.webkit && window.webkit.messageHandlers
    && window.webkit.messageHandlers.monoriCollectionLink;
  if (!handler) return;

  var username = match[1];
  var contentType = match[2];
  var workId = match[3];

  function post() {
    var parts = document.title.split(' | ');
    var title = (parts[0] || '').trim();
    if (!title) title = document.title.trim();

    var authorName = (parts[1] || '').trim();
    if (!authorName) {
      var storeEl = document.querySelector('a.store_name');
      authorName = storeEl ? storeEl.textContent.trim() : '';
    }
    if (!authorName) authorName = username;

    handler.postMessage({
      collectionName: title || 'CXC 作品',
      collectionURL: 'https://cxc.today/@' + username + '/' + contentType + '/' + workId,
      creatorName: authorName
    });
  }

  if (document.title.trim()) { post(); return; }

  var attempts = 0;
  var timer = setInterval(function () {
    attempts++;
    if (document.title.trim() || attempts >= 50) {
      clearInterval(timer);
      post();
    }
  }, 100);
})();
