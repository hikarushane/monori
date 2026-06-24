// Suppresses Patreon's own top gradient ("rainbow") loading bar inside the
// in-app web view.
//
// Patreon is a React SPA whose in-page navigations render a thin, full-width
// gradient progress bar pinned to the top of the viewport. That bar is web
// content — not the app's native SwiftUI ProgressView — so tinting the native
// bar never affected it. Patreon ships hashed CSS-module class names, so the bar
// cannot be targeted by a stable class selector. Instead we match it by its
// structural signature: an element pinned within a few px of the viewport top,
// only a few px tall, spanning most of the viewport width, and either a gradient
// fill or an explicitly positioned/progressbar element.
//
// The bar is mounted dynamically and can sit deep in the tree, so the scan is
// depth-independent (whole document) and runs for the page lifetime via a
// debounced subtree observer — a shallow, time-boxed scan misses it.
(function () {
  "use strict";

  function hasGradient(el) {
    try {
      var bi = getComputedStyle(el).backgroundImage || "";
      if (bi.indexOf("gradient") !== -1) return true;
    } catch (e) {}
    var kid = el.firstElementChild;
    if (kid) {
      try {
        var kbi = getComputedStyle(kid).backgroundImage || "";
        if (kbi.indexOf("gradient") !== -1) return true;
      } catch (e2) {}
    }
    return false;
  }

  function matches(el) {
    if (!el || el.nodeType !== 1 || el.dataset.monoriHid) return false;
    // Patreon's loading bar is a CSS-module component: the class hash rotates
    // between deploys but the "LoadingBar-module__" prefix is stable. Matching it
    // hides the bar the instant it mounts, before it can paint a frame.
    var cls = typeof el.className === "string" ? el.className : "";
    if (cls.indexOf("LoadingBar-module__") !== -1) return true;
    var role = el.getAttribute("role");
    if (el.id === "nprogress" || role === "progressbar") return true;
    var r = el.getBoundingClientRect();
    if (!(r.top <= 5 && r.height >= 1 && r.height <= 8 &&
          r.width >= window.innerWidth * 0.5)) return false;
    var pos = "";
    try { pos = getComputedStyle(el).position; } catch (e) {}
    var positioned = pos === "fixed" || pos === "absolute" || pos === "sticky";
    return positioned || hasGradient(el);
  }

  function report(el, action) {
    var diag = window.webkit &&
      window.webkit.messageHandlers &&
      window.webkit.messageHandlers.monoriLoadingBarDiag;
    if (!diag) return;
    var s = {};
    try { s = getComputedStyle(el); } catch (e) {}
    var r = el.getBoundingClientRect();
    diag.postMessage({
      action: action,
      tag: el.tagName,
      id: el.id || "",
      cls: (typeof el.className === "string" ? el.className : ""),
      role: el.getAttribute("role") || "",
      pos: s.position || "",
      h: Math.round(r.height),
      w: Math.round(r.width),
      top: Math.round(r.top),
      bg: (s.backgroundImage || "").slice(0, 140),
      html: el.outerHTML ? el.outerHTML.slice(0, 200) : ""
    });
  }

  function hide(el) {
    el.dataset.monoriHid = "1";
    el.style.setProperty("display", "none", "important");
    report(el, "hid");
  }

  function scan() {
    var root = document.body || document.documentElement;
    if (!root) return;
    // Fast path: hide by the known stable hooks first (cheap, no layout pass).
    var direct = root.querySelectorAll(
      '[class*="LoadingBar-module__"], #nprogress, [role="progressbar"]');
    for (var j = 0; j < direct.length; j++) {
      if (!direct[j].dataset.monoriHid) hide(direct[j]);
    }
    // Fallback: structural signature scan, so a class rename can't resurrect the
    // bar (thin, top-pinned, full-width, gradient element anywhere in the tree).
    var all = root.getElementsByTagName("*");
    var n = Math.min(all.length, 8000);
    for (var i = 0; i < n; i++) {
      var el = all[i];
      // Cheap pre-filter before the (layout-forcing) full match test. Always let
      // the explicit hooks (LoadingBar class, nprogress id, progressbar role)
      // through regardless of measured width.
      if (el.dataset.monoriHid) continue;
      var c = typeof el.className === "string" ? el.className : "";
      var explicit = c.indexOf("LoadingBar-module__") !== -1 ||
        el.id === "nprogress" || el.getAttribute("role") === "progressbar";
      if (!explicit && el.offsetWidth < window.innerWidth * 0.5) continue;
      if (matches(el)) hide(el);
    }
  }

  // Debounce scans to one per animation frame so a burst of SPA mutations during
  // navigation triggers a single pass.
  var queued = false;
  function schedule() {
    if (queued) return;
    queued = true;
    requestAnimationFrame(function () { queued = false; scan(); });
  }

  scan();
  schedule();
  document.addEventListener("DOMContentLoaded", schedule);
  window.addEventListener("load", schedule);

  function observe(target) {
    if (!target) return;
    try {
      new MutationObserver(schedule).observe(target, { childList: true, subtree: true });
    } catch (e) {}
  }
  if (document.documentElement) observe(document.documentElement);
  if (document.body) observe(document.body);
  else document.addEventListener("DOMContentLoaded", function () { observe(document.body); });
})();
