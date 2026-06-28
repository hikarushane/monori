"use strict";
var storyTitle = '';
var creatorName = '';
var titleEl = document.getElementById('story-title');
if (titleEl) storyTitle = titleEl.textContent.trim().substring(0, 256);
var authorLink = document.querySelector('.row-meta a[href^="/profile/u/"]');
if (authorLink) creatorName = authorLink.textContent.trim().substring(0, 256);

function collectFromSelect() {
  var sel = document.querySelector('select[name="chapter-nav"]');
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
var collected = [];

if (tocWidget) {
  var links = tocWidget.querySelectorAll('a[href^="/story/view/"]');
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
}

if (collected.length > 0) return collected;
return collectFromSelect();
