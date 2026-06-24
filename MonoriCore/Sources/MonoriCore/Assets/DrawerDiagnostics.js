(function () {
  "use strict";
  if (window.__monoriDrawerDiag) { return; }
  window.__monoriDrawerDiag = true;

  function send(kind, extra) {
    try {
      var mh = window.webkit && window.webkit.messageHandlers
        && window.webkit.messageHandlers.monoriDrawerDiag;
      if (!mh) { return; }
      mh.postMessage({
        kind: kind,
        t: Math.round(performance.now()),
        w: window.innerWidth,
        h: window.innerHeight,
        dpr: window.devicePixelRatio,
        sw: screen.width,
        sh: screen.height,
        vis: document.visibilityState,
        extra: extra || ""
      });
    } catch (e) {}
  }

  send("init");
  window.addEventListener("resize", function () { send("resize"); });
  window.addEventListener("focus", function () { send("focus"); }, true);
  window.addEventListener("blur", function () { send("blur"); }, true);
  window.addEventListener("pageshow", function () { send("pageshow"); });
  window.addEventListener("pagehide", function () { send("pagehide"); });
  document.addEventListener("visibilitychange",
    function () { send("visibilitychange"); }, true);

  // Heuristic drawer detector: a Material modal drawer inserts a near-full-screen
  // fixed-position backdrop/scrim. Logging when such a node is added/removed lets
  // us pin the drawer open/close moment against the events above.
  function looksLikeScrim(node) {
    if (!node || node.nodeType !== 1) { return false; }
    var s = window.getComputedStyle(node);
    if (s.position !== "fixed") { return false; }
    var r = node.getBoundingClientRect();
    return r.width >= window.innerWidth * 0.9
        && r.height >= window.innerHeight * 0.9;
  }
  new MutationObserver(function (muts) {
    for (var i = 0; i < muts.length; i++) {
      var m = muts[i];
      for (var a = 0; a < m.addedNodes.length; a++) {
        var n = m.addedNodes[a];
        if (looksLikeScrim(n)) {
          n.setAttribute("data-chap-scrim", "1");
          send("scrim-added");
        }
      }
      for (var r = 0; r < m.removedNodes.length; r++) {
        var rn = m.removedNodes[r];
        if (rn && rn.nodeType === 1 && rn.getAttribute("data-chap-scrim") === "1") {
          send("scrim-removed");
        }
      }
    }
  }).observe(document.documentElement, { childList: true, subtree: true });
})();
