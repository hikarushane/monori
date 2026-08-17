(function () {
  if (!/\/works\/\d+/.test(location.pathname)) return;

  var title = document.querySelector('h2.title.heading');
  if (!title) return;

  var match = location.pathname.match(/\/works\/(\d+)/);
  if (!match) return;

  var titleText = title.textContent.replace(/\s+/g, ' ').trim();
  var workURL = location.origin + '/works/' + match[1];

  // Co-authored works render one <a rel="author"> per creator.
  var authors = [];
  var authorLinks = document.querySelectorAll('a[rel="author"]');
  for (var i = 0; i < authorLinks.length; i++) {
    var name = (authorLinks[i].textContent || '').replace(/\s+/g, ' ').trim();
    if (name && authors.indexOf(name) === -1) { authors.push(name); }
  }

  window.webkit.messageHandlers.monoriCollectionLink.postMessage({
    collectionName: titleText,
    collectionURL: workURL,
    creatorName: authors.length ? authors.join(', ') : null
  });
})();
