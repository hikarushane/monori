"use strict";
var storyTitle = '';
var creatorName = '';
var titleEl = document.getElementById('story-title');
if (titleEl) storyTitle = titleEl.textContent.trim().substring(0, 256);
var authorLink = document.querySelector('.row-meta a[href^="/profile/u/"]');
if (authorLink) creatorName = authorLink.textContent.trim().substring(0, 256);

function collectFromSelect() {
  var sel = document.querySelector('select');
  if (!sel) return [];
  var collected = [];
  for (var i = 0; i < sel.options.length; i++) {
    var opt = sel.options[i];
    var val = opt.value || '';
    if (!val || val.indexOf('/story/view/') === -1) continue;
    collected.push({
      title: opt.textContent.trim().substring(0, 256),
      url: 'https://www.asianfanfics.com' + val.split('?')[0],
      creatorName: creatorName,
      collectionName: storyTitle,
      collectionURL: location.href,
      domOrder: collected.length
    });
  }
  return collected;
}

var tocWidget = document.querySelector('.widget--chapters');
// Collapsed TOC: widget exists but server sent fewer links. The expand
// toggle link is the signal. Fall back to <select> which always has all
// chapters regardless of the collapse preference.
if (!tocWidget || tocWidget.querySelector('a[href*="toggle_full_chapter_nav"]')) {
  return collectFromSelect();
}

var links = tocWidget.querySelectorAll('a[href^="/story/view/"]');
var collected = [];

for (var i = 0; i < links.length; i++) {
  var a = links[i];
  var href = a.getAttribute('href') || '';
  if (!href) continue;
  collected.push({
    title: a.textContent.trim().substring(0, 256),
    url: 'https://www.asianfanfics.com' + href.split('?')[0],
    creatorName: creatorName,
    collectionName: storyTitle,
    collectionURL: location.href,
    domOrder: i
  });
}

return collected;
