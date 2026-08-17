"use strict";
// Runs as the body of an async function (WKWebView callAsyncJavaScript), so the
// value has to be returned explicitly.
// Returns the chapter body of a single-chapter AO3 work, or null.
//
// The summary and the author notes are blockquote.userstuff and sit before the
// chapter in the DOM, so a bare `.userstuff` selector imports the summary as
// the chapter. Select the chapter div the way AO3ChapterSplitter
// .extractChapterContent does on the Swift side.
var node = document.querySelector("#chapters div.userstuff")
  || document.querySelector("div.userstuff");
return node ? node.innerHTML : null;
