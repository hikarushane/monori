"use strict";
// Runs as the body of an async function (WKWebView callAsyncJavaScript), so the
// value has to be returned explicitly — a bare expression resolves to
// `undefined` and reaches Swift as nil.
// Returns { title, author } for the AO3 work page currently displayed.
function compactText(node) {
  if (!node) { return null; }
  var text = (node.textContent || "").replace(/\s+/g, " ").trim();
  return text || null;
}

// AO3 wraps the title across several lines inside h2.title.heading.
var title = compactText(document.querySelector("h2.title.heading"));

// Co-authored works render one <a rel="author"> per creator.
var authors = [];
var authorLinks = document.querySelectorAll('a[rel="author"]');
for (var i = 0; i < authorLinks.length; i++) {
  var name = compactText(authorLinks[i]);
  if (name && authors.indexOf(name) === -1) { authors.push(name); }
}

return { title: title, author: authors.length ? authors.join(", ") : null };
