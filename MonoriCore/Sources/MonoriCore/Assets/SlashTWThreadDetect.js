(function () {
  // Detects a slashtw (在水裡寫字 / Waterfall) thread page and posts its
  // metadata to the monoriCollectionLink handler so the app shows the
  // "Import chapters" banner.
  //
  // URL shapes (both handled by URLNormalizer.slashtwThreadID):
  //   waterfall.slashtw.space/thread/{id}          — new Waterfall form
  //   slashtw.space/forum.php?mod=viewthread&tid=N  — legacy Discuz form
  //
  // Waterfall requires a logged-in session to view thread content.
  // This script only fires after the user has manually signed in.
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

  // Thread title: h1 > a.title-link inside the first card-post.thread,
  // fallback to document.title minus the " - 在水裡寫字" suffix.
  var h1 = document.querySelector('h1');
  var title = h1 ? h1.textContent.trim() : null;
  if (!title) {
    title = document.title.replace(/\s*-\s*在水裡寫字\s*$/, '').trim();
  }

  // Author: first .author-info link pointing to /user/{username}.
  var authorLink = document.querySelector('.author-info a[href*="/user/"]');
  var author = authorLink ? authorLink.textContent.trim() : null;

  handler.postMessage({
    collectionName: title,
    collectionURL: 'https://waterfall.slashtw.space/thread/' + threadId,
    creatorName: author
  });
})();
