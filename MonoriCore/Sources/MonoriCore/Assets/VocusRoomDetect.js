(function () {
  if (location.hostname !== 'vocus.cc') return;
  if (!/\/salon\/[0-9a-f]{24}\/room\//.test(location.pathname)) return;

  var articleLinks = document.querySelectorAll('a[href^="/article/"]');
  if (!articleLinks.length) return;

  var handler = window.webkit && window.webkit.messageHandlers
    && window.webkit.messageHandlers.monoriCollectionLink;
  if (!handler) return;

  function roomTitleFromTabs() {
    var tabs = document.querySelectorAll('a[role="tab"][aria-selected="true"], [class*="active"] a[href*="/room/"]');
    for (var i = 0; i < tabs.length; i++) {
      var text = (tabs[i].textContent || '').trim();
      if (text && text.length < 100) return text;
    }
    return null;
  }

  function roomTitleFromPageTitle() {
    var title = document.title || '';
    var sep = title.indexOf('｜');
    if (sep > 0) return title.substring(0, sep).trim();
    return null;
  }

  function roomSlugFromURL() {
    var parts = location.pathname.split('/').filter(Boolean);
    return parts.length >= 4 ? decodeURIComponent(parts[3]) : null;
  }

  function salonNameFromHeader() {
    var h1 = document.querySelector('h1');
    if (h1) {
      var text = (h1.textContent || '').trim();
      if (text && text.length < 100) return text;
    }
    var meta = document.querySelector('meta[property="og:site_name"]');
    if (meta) {
      var content = (meta.getAttribute('content') || '').trim();
      if (content) return content;
    }
    return null;
  }

  var roomTitle = roomTitleFromTabs() || roomTitleFromPageTitle() || roomSlugFromURL() || 'Vocus Room';
  var creatorName = salonNameFromHeader();

  handler.postMessage({
    collectionName: roomTitle,
    collectionURL: location.href,
    creatorName: creatorName
  });
})();
