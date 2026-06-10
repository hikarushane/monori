(function () {
  "use strict";
  if (window.__chapterlyProgressInstalled) { return; }
  window.__chapterlyProgressInstalled = true;
  var handler = window.webkit && window.webkit.messageHandlers
    && window.webkit.messageHandlers.chapterlyProgress;
  if (!handler) { return; }
  var pending = null;
  window.addEventListener("scroll", function () {
    if (pending) { return; }
    pending = setTimeout(function () {
      pending = null;
      var doc = document.documentElement;
      var max = doc.scrollHeight - window.innerHeight;
      var p = max > 0 ? Math.min(1, Math.max(0, window.scrollY / max)) : 0;
      handler.postMessage({ url: location.href, scrollProgress: p });
    }, 500);
  }, { passive: true });
})();
