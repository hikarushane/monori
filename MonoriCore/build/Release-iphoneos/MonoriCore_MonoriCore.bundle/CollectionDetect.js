(function () {
  "use strict";
  var handler = window.webkit && window.webkit.messageHandlers
    && window.webkit.messageHandlers.monoriCollectionLink;
  if (!handler) { return; }
  var a = document.querySelector('a[href*="/collection/"]');
  if (!a) { return; }
  handler.postMessage({
    collectionName: (a.textContent || "").trim().slice(0, 512),
    collectionURL: a.href
  });
})();
