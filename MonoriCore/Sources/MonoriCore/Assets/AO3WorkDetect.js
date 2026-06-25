(function () {
  if (!/\/works\/\d+/.test(location.pathname)) return;

  var title = document.querySelector('h2.title.heading');
  if (!title) return;

  var match = location.pathname.match(/\/works\/(\d+)/);
  if (!match) return;

  var titleText = title.textContent.trim();
  var workURL = location.origin + '/works/' + match[1];

  window.webkit.messageHandlers.monoriCollectionLink.postMessage({
    collectionName: titleText,
    collectionURL: workURL
  });
})();
