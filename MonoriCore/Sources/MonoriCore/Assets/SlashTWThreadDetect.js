(function () {
  // Detects a slashtw (在水裡寫字) thread page and posts its metadata to the
  // monoriCollectionLink handler, matching the CXC/Vocus/AFF/AO3 detect
  // scripts' contract so the app can show the "Import chapters" banner (see
  // CXCWorkDetect.js). URL shape mirrors URLNormalizer's slashtw parsing
  // (isSlashTWHost / slashtwThreadID): either the new Waterfall form
  // waterfall.slashtw.space/thread/{id}, or the legacy Discuz form
  // slashtw.space/forum.php?mod=viewthread&tid={id} -- the old host currently
  // redirects to the new one and both forms may still be encountered.
  //
  // Waterfall requires a logged-in session to see thread content at all, so
  // in practice this only ever fires after the user has manually signed in
  // (real Patreon/forum login is always a manual step -- see
  // SIMULATOR_PLAYBOOK.md / CLAUDE.md Patreon Login Rules; the same policy
  // extends to any third-party auth gate this app injects scripts into).
  var host = location.hostname.toLowerCase();
  if (host !== 'slashtw.space' && !host.endsWith('.slashtw.space')) return;

  var threadId = null;
  var segments = location.pathname.split('/').filter(Boolean);
  var threadIdx = segments.indexOf('thread');
  if (threadIdx !== -1 && threadIdx + 1 < segments.length && /^\d+$/.test(segments[threadIdx + 1])) {
    threadId = segments[threadIdx + 1];
  } else if (segments.length === 1 && segments[0] === 'forum.php') {
    var params = new URLSearchParams(location.search);
    if (params.get('mod') === 'viewthread') {
      var tid = params.get('tid');
      if (tid && /^\d+$/.test(tid)) threadId = tid;
    }
  }
  if (!threadId) return;

  var handler = window.webkit && window.webkit.messageHandlers
    && window.webkit.messageHandlers.monoriCollectionLink;
  if (!handler) return;

  // DOM selectors are generic placeholders pending real DevTools inspection
  // of waterfall.slashtw.space (the page requires a logged-in session to
  // reach at all); refine once the real markup is confirmed.
  // TODO: verify with DevTools
  var titleEl = document.querySelector('h1, [class*="title"], [class*="subject"]');
  var authorEl = document.querySelector('[class*="author"], [class*="username"], [class*="poster"]');

  var title = titleEl ? titleEl.textContent.trim() : document.title;
  // Unlike CXC's /@username/work/N URLs, a slashtw thread URL carries no
  // author identifier to fall back to, so an unmatched author element means
  // an unknown creator -- null, same as AFFStoryDetect.js's fallback when its
  // author link is missing.
  var author = authorEl ? authorEl.textContent.trim() : null;

  handler.postMessage({
    collectionName: title,
    collectionURL: 'https://waterfall.slashtw.space/thread/' + threadId,
    creatorName: author
  });
})();
