(function () {
  "use strict";
  var handler = window.webkit && window.webkit.messageHandlers
    && window.webkit.messageHandlers.chapterlyImport;
  if (!handler) { return; }

  var h1 = document.querySelector("h1");
  var collectionName = ((h1 && h1.textContent) || document.title || "").trim().slice(0, 512);
  var collectionURL = location.href;

  var seen = {};
  var order = 0;
  var anchors = document.querySelectorAll('a[href*="/posts/"]');
  for (var i = 0; i < anchors.length; i++) {
    var a = anchors[i];
    var href = a.href || "";
    if (!href || seen[href]) { continue; }
    var title = (a.textContent || "").trim().slice(0, 512);
    if (!title) { continue; }
    seen[href] = true;
    handler.postMessage({
      title: title,
      url: href,
      visibleDateText: null,
      collectionName: collectionName,
      collectionURL: collectionURL,
      domOrder: order
    });
    order += 1;
  }
})();
