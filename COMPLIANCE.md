# Chapterly Compliance Notes

## What Chapterly is

A local-only iOS reading shell. The user logs into patreon.com inside the app's
WKWebView with their own account. Patreon serves every page and enforces all
access control. Chapterly only restyles what Patreon already shows the user and
remembers chapter links and reading position locally.

## What Chapterly never does

- Never reads, copies, or exports session cookies or website data
  (the `WKWebsiteDataStore` is only ever wiped on logout, never enumerated)
- Never intercepts Patreon network responses
- Never calls Patreon APIs (official or internal)
- Never stores post bodies or page HTML — a strict native-side payload
  validator rejects any script message containing content-like fields
  (`bodyText`, `innerHTML`, `html`, `content`, ...), unknown keys, or
  oversized payloads
- Never provides offline reading, export, or sharing of paid content
- Never aggregates content across users (there is no backend at all)
- Never sends post content to analytics, crash logs, or AI APIs (none are integrated)

## What is stored locally

Chapter titles, Patreon post URLs, visible date strings, manual ordering,
collection names/URLs, creator names, reading progress percentages, font preferences.
Nothing else.

## Data deletion

- **Clear Library Data** (Settings) deletes all stored metadata.
- **Logout from Patreon** (Settings) wipes the webview website data store,
  ending the session.

## When access is revoked

Nothing is cached, so a revoked membership simply shows Patreon's own locked
page inside the webview. Chapterly has no content to keep showing.

## Remaining risks

- Client-side restyling of a logged-in page is comparable to Safari Reader
  Mode or a content blocker, but Patreon's Terms of Use do not explicitly
  bless it. Chapterly is distributed as sideloaded, open-source, personal-use
  software partly for this reason.
- Patreon markup changes can break the reader CSS and the collection importer.
  Degradation is graceful (plain Patreon page; manual chapter entry).
