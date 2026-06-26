"use strict";
function compactText(value) {
  return (value || '').replace(/\s+/g, ' ').trim();
}

function limitField(value) {
  return compactText(value).slice(0, 256);
}

function articleIDFromHref(href) {
  var match = href.match(/\/article\/([0-9a-f]{24})/);
  return match ? match[1] : null;
}

function titleForLink(anchor) {
  var heading = anchor.querySelector('h1, h2, h3, h4');
  if (heading) {
    var text = compactText(heading.textContent);
    if (text && text.length <= 180) return text;
  }
  var text = compactText(anchor.textContent);
  var lines = text.split(/\n+/).map(compactText).filter(Boolean);
  if (lines.length > 0 && lines[0].length <= 180) return lines[0];
  return text.slice(0, 180) || 'Untitled';
}

function excerptNear(anchor) {
  var node = anchor.parentElement;
  for (var depth = 0; node && depth < 4; depth++) {
    var ps = node.querySelectorAll('p');
    for (var i = 0; i < ps.length; i++) {
      var text = compactText(ps[i].textContent);
      if (text.length >= 10 && text.length <= 300) return text;
    }
    node = node.parentElement;
  }
  return null;
}

function creatorNameFromPage() {
  var parts = location.pathname.split('/').filter(Boolean);
  if (parts.length >= 2 && parts[0] === 'salon') {
    return decodeURIComponent(parts[1]);
  }
  var h1 = document.querySelector('h1');
  if (h1) {
    var text = compactText(h1.textContent);
    if (text && text.length < 100) return text;
  }
  return null;
}

function sleep(ms) {
  return new Promise(function (resolve) { setTimeout(resolve, ms); });
}

var seen = {};
var collected = [];
var authorName = limitField(creatorNameFromPage());

function roomTitleFromPage() {
  var title = document.title || '';
  var sep = title.indexOf('｜');
  if (sep > 0) {
    var t = title.substring(0, sep).trim();
    if (t) return t;
  }
  var h1 = document.querySelector('h1');
  if (h1) {
    var text = compactText(h1.textContent);
    if (text && text.length < 100) return text;
  }
  var parts = location.pathname.split('/').filter(Boolean);
  if (parts.length >= 4 && parts[2] === 'room') {
    var slug = decodeURIComponent(parts[3]);
    if (slug) return slug;
  }
  var tabs = document.querySelectorAll('a[role="tab"][aria-selected="true"], [class*="active"] a[href*="/room/"]');
  for (var i = 0; i < tabs.length; i++) {
    var text = compactText(tabs[i].textContent);
    if (text && text.length < 100) return text;
  }
  return 'Vocus Room';
}

var roomTitle = limitField(roomTitleFromPage());

function collectVisible() {
  var anchors = document.querySelectorAll('a[href^="/article/"]');
  for (var i = 0; i < anchors.length; i++) {
    var a = anchors[i];
    var href = a.getAttribute('href') || '';
    var articleID = articleIDFromHref(href);
    if (!articleID || seen[articleID]) continue;
    seen[articleID] = true;
    collected.push({
      title: limitField(titleForLink(a)),
      url: 'https://vocus.cc' + href.split('?')[0],
      excerpt: excerptNear(a),
      creatorName: authorName,
      collectionName: roomTitle,
      collectionURL: location.href,
      domOrder: collected.length
    });
  }
}

var previousCount = -1;
var stableRounds = 0;
for (var round = 0; round < 10; round++) {
  collectVisible();
  window.scrollTo(0, document.documentElement.scrollHeight);
  await sleep(1500);
  var count = Object.keys(seen).length;
  if (count !== previousCount) {
    stableRounds = 0;
    previousCount = count;
  } else {
    stableRounds += 1;
    if (stableRounds >= 2) break;
  }
}
collectVisible();
window.scrollTo(0, 0);

return collected;
