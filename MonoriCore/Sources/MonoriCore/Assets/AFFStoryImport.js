"use strict";
// AsianFanfics 2026 redesign. The story page marks each table-of-contents row
// with `data-toc-chapter` ("0" = Foreword, 1..N = chapters), and renders the
// whole TOC twice — once in the desktop `aside`, once in the mobile `<dialog>`
// — so the collector dedupes by chapter number. The client-inserted
// "▶ Continue" row carries no `data-toc-chapter`, so it drops out for free.
var storyTitle = '';
var creatorName = '';

// Three <header> elements exist (language bar, site nav, story header); only
// the story header holds an <h1>. Anchoring on that survives class churn.
var storyHeader = null;
var headerCandidates = document.querySelectorAll('header');
for (var hi = 0; hi < headerCandidates.length; hi++) {
  if (headerCandidates[hi].querySelector('h1')) { storyHeader = headerCandidates[hi]; break; }
}
if (storyHeader) {
  storyTitle = storyHeader.querySelector('h1').textContent.trim().substring(0, 256);
  var authorLink = storyHeader.querySelector('a[href^="/profile/u/"]');
  if (authorLink) creatorName = authorLink.textContent.trim().substring(0, 256);
}

function currentStoryID() {
  var parts = location.pathname.split('/').filter(Boolean);
  if (parts.length < 3 || parts[0] !== 'story' || parts[1] !== 'view') return '';
  return /^\d+$/.test(parts[2]) ? parts[2] : '';
}

// Row anchors prefix the label with a decorative number badge inside
// <span aria-hidden="true">. Strip aria-hidden nodes so the stored title is
// "Chapter 3: …" and not "3 Chapter 3: …".
function visibleText(anchor) {
  var clone = anchor.cloneNode(true);
  var hidden = clone.querySelectorAll('[aria-hidden="true"]');
  for (var i = 0; i < hidden.length; i++) { hidden[i].parentNode.removeChild(hidden[i]); }
  return clone.textContent.trim().replace(/\s+/g, ' ').substring(0, 256);
}

function absoluteURL(href) {
  if (!href) return '';
  return new URL(href, location.href).href.split('?')[0].split('#')[0];
}

function makeChapter(number, href, title) {
  return {
    title: title,
    url: absoluteURL(href),
    creatorName: creatorName,
    collectionName: storyTitle,
    collectionURL: location.href,
    chapterNumber: number
  };
}

function collectFromTOC() {
  var byNumber = {};
  var anchors = document.querySelectorAll('a[data-toc-chapter]');
  for (var i = 0; i < anchors.length; i++) {
    var a = anchors[i];
    var raw = a.getAttribute('data-toc-chapter');
    if (!/^\d+$/.test(raw)) continue;
    var n = parseInt(raw, 10);
    if (n === 0) continue;            // Foreword is story notes, not a chapter
    if (byNumber[n]) continue;        // aside and dialog carry the same rows
    byNumber[n] = makeChapter(n, a.getAttribute('href'), visibleText(a));
  }
  return byNumber;
}

// Fallback when no `data-toc-chapter` row exists (single-chapter stories, or a
// future markup change): scan every link pointing at a numbered chapter of THIS
// story. Several links can share a chapter number ("Start reading →",
// "Next chapter →", the real label); the longest label wins.
function collectFromLinks() {
  var id = currentStoryID();
  var byNumber = {};
  if (!id) return byNumber;
  var anchors = document.querySelectorAll('a[href]');
  for (var i = 0; i < anchors.length; i++) {
    var a = anchors[i];
    var abs = absoluteURL(a.getAttribute('href'));
    if (!abs) continue;
    var parts = abs.replace(/^https?:\/\/[^/]+/, '').split('/').filter(Boolean);
    if (parts.length < 4 || parts[0] !== 'story' || parts[1] !== 'view') continue;
    if (parts[2] !== id || !/^\d+$/.test(parts[3])) continue;
    var n = parseInt(parts[3], 10);
    var title = visibleText(a);
    if (byNumber[n] && byNumber[n].title.length >= title.length) continue;
    byNumber[n] = makeChapter(n, a.getAttribute('href'), title);
  }
  return byNumber;
}

function flatten(byNumber) {
  var out = [];
  for (var key in byNumber) {
    if (Object.prototype.hasOwnProperty.call(byNumber, key)) { out.push(byNumber[key]); }
  }
  out.sort(function (a, b) { return a.chapterNumber - b.chapterNumber; });
  for (var i = 0; i < out.length; i++) { out[i].domOrder = i; }
  return out;
}

var chapters = flatten(collectFromTOC());
if (chapters.length === 0) { chapters = flatten(collectFromLinks()); }
return chapters;
