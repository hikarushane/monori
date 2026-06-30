(function () {
  if (location.hostname !== 'vocus.cc' && !location.hostname.endsWith('.vocus.cc')) return;
  if (!/\/salon\/[^/]+\/room\//.test(location.pathname)) return;

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

  function creatorNameFromNextData() {
    try {
      var sd = window.__NEXT_DATA__.props.pageProps.salonData;
      if (sd) {
        if (sd.owner && sd.owner.fullname) return sd.owner.fullname.trim();
        if (sd.name) {
          var n = sd.name.trim();
          var suffix = '的沙龍';
          if (n.endsWith(suffix)) return n.slice(0, -suffix.length).trim();
          return n;
        }
      }
    } catch (e) {}
    return null;
  }

  function creatorNameFromURL() {
    var parts = location.pathname.split('/').filter(Boolean);
    if (parts.length >= 2 && parts[0] === 'salon') {
      return decodeURIComponent(parts[1]);
    }
    return null;
  }

  var roomTitle = roomTitleFromPageTitle() || salonNameFromHeader() || roomSlugFromURL() || roomTitleFromTabs() || 'Vocus Room';
  var creatorName = creatorNameFromNextData() || creatorNameFromURL();

  handler.postMessage({
    collectionName: roomTitle,
    collectionURL: location.href,
    creatorName: creatorName
  });
})();
