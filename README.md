# Monori

A calm, local-only reading shell for your own Patreon session. Log into
patreon.com inside the app, import a series' chapter list from its collection
page, and read with clean typography, previous/next chapter navigation, and
bookmarks you can set per chapter.

Monori is **not** a Patreon client or API consumer. It never bypasses
access control, never stores post content, and has no backend. See
[COMPLIANCE.md](COMPLIANCE.md).

## Requirements

- Xcode 15.4+ (iOS 17 SDK)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- An iPhone (sideload) or the iOS simulator

## Build

```bash
git clone <this repo>
cd Monori
xcodegen generate
open Monori.xcodeproj
```

Select the Monori scheme, set your own signing team (Signing & Capabilities),
and run on a device or simulator.

## Tests

```bash
swift test --package-path MonoriCore
```

## Sideloading for non-developers

Any of: AltStore / SideStore with the built `.ipa`, or a free Apple developer
certificate in Xcode (7-day resign cycle), or an Apple Developer Program
membership (1-year certificates). Each user signs the app themselves and logs
in with their own Patreon account.

## Using the app

1. **Browse** tab → log into patreon.com (email login; third-party SSO that
   leaves patreon.com opens in Safari by design — prefer email login).
2. Open a post in a series → tap **Open collection** when the series banner
   appears → on the collection page tap **Import all chapters** (the script
   scrolls automatically; re-imports merge without duplicates).
3. **Library** tab → pick the collection → tap a chapter to read. Collections
   you mark as **追更中 (reading)** are checked for new chapters automatically in
   the foreground (toggle in Settings); new chapters get an unread badge and a
   dot in the table of contents. Sort (title / recently updated / recently read),
   search by title or author, and filter by reading status from the toolbar
   menu; pull to refresh checks all reading collections now. Per collection, tap
   **•••** → set its reading status, or **Check for new chapters** to import
   manually. (Automatic checking supports Patreon today; other sources still use
   the manual **Check for new chapters** action.)
4. Reader: chrome hidden by default — tap the page center to show/hide bars.
   Bookmark top-left; font size + line spacing in the preferences panel
   (⊤T button, top-right). Left-edge swipe to leave. Previous/next chapter
   in the bottom bar.

## Known limitations

- Patreon markup changes can break reader styling and import — both degrade
  gracefully; chapter lists can always be re-imported from the Browse tab.
- No offline reading, by design.

## What not to implement

Cookie access, network interception, Patreon API calls, content storage or
export, cross-user sharing — see COMPLIANCE.md. Pull requests adding any of
these will be declined.
