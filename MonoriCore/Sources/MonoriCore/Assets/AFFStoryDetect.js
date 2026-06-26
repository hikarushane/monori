(function () {
  var host = location.hostname;
  if (host !== 'www.asianfanfics.com' && host !== 'asianfanfics.com') return;

  var parts = location.pathname.split('/').filter(Boolean);
  if (parts.length < 3 || parts[0] !== 'story' || parts[1] !== 'view') return;
  if (!/^\d+$/.test(parts[2])) return;
  if (parts.length >= 4 && /^\d+$/.test(parts[3])) return;
  if (parts.length >= 5) return;

  var title = document.getElementById('story-title');
  if (!title) return;

  var handler = window.webkit && window.webkit.messageHandlers
    && window.webkit.messageHandlers.monoriCollectionLink;
  if (!handler) return;

  var authorLink = document.querySelector('.row-meta a[href^="/profile/u/"]');
  var creatorName = authorLink ? authorLink.textContent.trim() : null;

  handler.postMessage({
    collectionName: title.textContent.trim(),
    collectionURL: location.href,
    creatorName: creatorName
  });
})();
