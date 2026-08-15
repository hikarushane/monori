(function () {
  var host = location.hostname;
  if (host !== 'www.asianfanfics.com' && host !== 'asianfanfics.com') return;

  var parts = location.pathname.split('/').filter(Boolean);
  if (parts.length < 3 || parts[0] !== 'story' || parts[1] !== 'view') return;
  if (!/^\d+$/.test(parts[2])) return;
  if (parts.length >= 4 && /^\d+$/.test(parts[3])) return;
  if (parts.length >= 5) return;

  // Three <header> elements exist (language bar, site nav, story header);
  // only the story header holds an <h1>. See AFFStoryImport.js.
  var storyHeader = null;
  var headerCandidates = document.querySelectorAll('header');
  for (var i = 0; i < headerCandidates.length; i++) {
    if (headerCandidates[i].querySelector('h1')) { storyHeader = headerCandidates[i]; break; }
  }
  if (!storyHeader) return;

  var handler = window.webkit && window.webkit.messageHandlers
    && window.webkit.messageHandlers.monoriCollectionLink;
  if (!handler) return;

  var authorLink = storyHeader.querySelector('a[href^="/profile/u/"]');

  handler.postMessage({
    collectionName: storyHeader.querySelector('h1').textContent.trim(),
    collectionURL: location.href,
    creatorName: authorLink ? authorLink.textContent.trim() : null
  });
})();
