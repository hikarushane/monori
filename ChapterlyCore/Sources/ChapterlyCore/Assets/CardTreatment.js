(function () {
  "use strict";
  if (window.__chapterlyCardTreatment) { return; }
  window.__chapterlyCardTreatment = true;

  var STYLE_ID = "chapterly-card-style";

  function ensureStyle() {
    if (document.getElementById(STYLE_ID)) { return; }
    var style = document.createElement("style");
    style.id = STYLE_ID;
    style.textContent =
      '[data-tag="post-card"]{-webkit-user-select:none;user-select:none;cursor:pointer;}' +
      '[data-tag="post-card"] .chapterly-fade{position:relative;max-height:10em;overflow:hidden;' +
      '-webkit-mask-image:linear-gradient(180deg,#000 60%,transparent 100%);' +
      'mask-image:linear-gradient(180deg,#000 60%,transparent 100%);}';
    document.documentElement.appendChild(style);
  }

  function compact(value) {
    return (value || "").replace(/\s+/g, " ").trim();
  }

  function isShowMoreLabel(value) {
    var label = compact(value).toLowerCase();
    if (!label || label.length > 20) { return false; }
    return /^(show|see|read|view)\s+more/.test(label)
      || /^(顯示|显示|查看|閱讀|阅读)更多/.test(label)
      || /^(繼續閱讀|继续阅读|展開|展开)/.test(label);
  }

  function collapseShowMore(card) {
    var candidates = card.querySelectorAll('button, [role="button"], a');
    for (var i = 0; i < candidates.length; i++) {
      var el = candidates[i];
      if (el.matches('a[href*="/posts/"]')) { continue; }
      if (!isShowMoreLabel(el.textContent)) { continue; }
      var teaser = el.previousElementSibling;
      if (teaser && compact(teaser.textContent)) {
        teaser.classList.add("chapterly-fade");
      }
      el.style.display = "none";
    }
  }

  function treatCard(card) {
    if (card.__chapterlyTreated) { return; }
    var link = card.querySelector('a[href*="/posts/"]');
    if (!link) { return; }
    card.__chapterlyTreated = true;
    card.addEventListener("click", function (event) {
      if (event.defaultPrevented) { return; }
      var interactive = event.target.closest(
        'a, button, [role="button"], input, textarea, select, video, audio');
      if (interactive) { return; }
      link.click();
    });
    collapseShowMore(card);
  }

  function scan() {
    ensureStyle();
    var cards = document.querySelectorAll('[data-tag="post-card"]');
    for (var i = 0; i < cards.length; i++) {
      treatCard(cards[i]);
    }
  }

  scan();

  // Patreon renders and replaces cards client-side; rescan (throttled) as the
  // SPA mutates the page.
  var scheduled = false;
  new MutationObserver(function () {
    if (scheduled) { return; }
    scheduled = true;
    setTimeout(function () {
      scheduled = false;
      scan();
    }, 300);
  }).observe(document.documentElement, { childList: true, subtree: true });
})();
