# Monori App Review Guide

This guide is provided for App Review to explain how to test Monori's
main features.

Monori is a local-first reading app. It allows users to browse content
through supported websites and explicitly import accessible content into
a local Library for reading.

Monori does not operate a Monori backend, content proxy, shared cloud
content service, analytics service, advertising service, or cross-user
content service. Optional backup uses the user's own private
iCloud/CloudKit storage.

------------------------------------------------------------------------

## Important Review Account Information

**Monori does not provide account creation and does not maintain Monori
user accounts.**

Patreon and Google Docs are third-party websites displayed inside
Monori's `WKWebView`. Any login, sign-up, profile, account-management,
or account-deletion UI displayed by those websites belongs to the
respective third-party service.

For App Review, **please use the Google review account and credentials
provided in App Store Connect's App Review Information** for both
Patreon and Google Docs. It is not necessary to create a new Patreon or
Google account.

For Patreon, choose **Log in / Continue with Google** and use the
provided Google review account. Please do not use Patreon's **Sign up**
flow for testing Monori. A Patreon account created on the Patreon
website is a Patreon account and is not created, stored, or managed by
Monori.

If Google blocks the login because of the review location or requests
additional verification, please contact us through App Store Connect
messages. We can approve the login attempt or provide the required
verification code promptly.

------------------------------------------------------------------------

## 1. App Navigation

Monori has three main tabs:

  Tab        Purpose
  ---------- -------------------------------------------------
  Browser    Browse supported websites and import content
  Library    Read imported works and manage reading progress
  Settings   Configure app and reading preferences

### Browser

The source selector at the top of the Browser tab provides five
supported sources:

1.  Patreon
2.  Vocus
3.  Archive of Our Own (AO3)
4.  Google Docs
5.  AsianFanfics (AFF)

Each source uses its own website session managed by `WKWebView`.

------------------------------------------------------------------------

## 2. Demo Content

The following works were created or uploaded by the developer
specifically for App Review testing.

They provide predictable content without requiring reviewers to search
for arbitrary third-party works.

  ----------------------------------------------------------------------------------------------
  Source            Login             Demo account /    Demo content
                                      search            
  ----------------- ----------------- ----------------- ----------------------------------------
  Vocus             No                Search `hikaruHa` 「我在便利商店等一場雪」

  Patreon           Yes               Search `hikaruHa` 「霧港三號倉庫」

  AO3               No                Search            「紙上幽靈」
                                      `shane_y747`      

  Google Docs       Yes               Shared with me    「鏽鐵之夏」

  AsianFanfics      No                Search            「第十七次登出：一個沒有伺服器的世界」
                                      `monoriappdemo`   
  ----------------------------------------------------------------------------------------------

Google Docs requires the Google review account whose credentials are
provided in App Store Connect's App Review Information.

Patreon uses the same provided Google review account. On Patreon's
website, choose **Log in / Continue with Google** rather than creating a
new Patreon account.

------------------------------------------------------------------------

## 3. Importing Content

The Import button appears only on supported page types.

For App Review testing, please use the demo content listed below.

### 3.1 Vocus

**Login required:** No

#### Steps

1.  Open Browser.
2.  Select Vocus from the source selector.
3.  Search for `hikaruHa`.
4.  Open the room 「我在便利商店等一場雪」.
5.  The Import / 匯入 button appears on the supported room page.
6.  Tap Import / 匯入.

The imported work will appear in the Library tab.

### 3.2 Patreon

**Login required:** Yes

#### Steps

1.  Open Browser.
2.  Select Patreon.
3.  Choose **Log in / Continue with Google**.
4.  Sign in using the Google review account provided in App Store
    Connect.
5.  Search for `hikaruHa`.
6.  Open the Collection 「霧港三號倉庫」.
7.  The Import / 匯入 control is available on the Collection page.
8.  Tap Import / 匯入.

The Patreon demo content belongs to the developer's account. The
Collection page is the intended testing page for the Patreon importer.

**Please do not create a new Patreon account for review.** Patreon's
sign-up, profile, Settings, creator, logout, and account-management
screens are third-party Patreon webpages and are not Monori account
functionality.

### 3.3 Archive of Our Own (AO3)

**Login required:** No

#### Steps

1.  Open Browser.
2.  Select AO3.
3.  Search for `shane_y747`.
4.  Open the work 「紙上幽靈」.
5.  The Import / 匯入 control appears on the work page.
6.  Tap Import / 匯入.

No account is required for this demo work.

### 3.4 Google Docs

**Login required:** Yes

#### Steps

1.  Open Browser.
2.  Select Google Docs.
3.  Sign in using the Google review account provided in App Store
    Connect.
4.  Open Shared with me / 與我共享.
5.  Open the document 「鏽鐵之夏」.
6.  The Import / 匯入 control appears in the supported document view.
7.  Tap Import / 匯入.

The document was created by the developer specifically for App Review
testing.

Google Docs is treated as a static document. Automatic chapter-update
detection is not available for this source.

### 3.5 AsianFanfics (AFF)

**Login required:** No

#### Steps

1.  Open Browser.
2.  Select AFF.
3.  Search for `monoriappdemo`.
4.  Open the story 「第十七次登出：一個沒有伺服器的世界」.
5.  The Import / 匯入 control appears on the supported story page.
6.  Tap Import / 匯入.

No account is required for this demo story.

------------------------------------------------------------------------

## 4. Library

### 4.1 Import confirmation

After a successful import, Monori displays a confirmation message
showing the number of imported chapters.

When the same work is imported again, existing chapters are merged with
the collection instead of creating duplicate chapters.

After importing a work, open the Library tab.

Imported works appear as collections in the user's local reading
library. Tap a collection to view its chapters.

The Library provides:

-   Collection management
-   Chapter navigation
-   Reading progress
-   Reading status (追更中 / 完食 / 棄坑)
-   Reading history (閱歷)
-   Bookmarks
-   Search and sorting
-   Update checking for supported sources

### Status scope

The Library header displays a status dropdown next to the title: 追更中
(Reading), 完食 (Finished), and 棄坑 (Dropped). The default view shows
works with the Reading status. Users can change a work's status from the
chapter list menu. Marking a work as Finished clears its unread badges
but preserves bookmarks, reading progress, and history.

### Reading history

Tap the clock icon in the Library header to view reading history. Each
entry records when a chapter was opened, grouped by date. Tapping an
entry reopens the chapter. Entries for deleted works remain visible but
cannot be reopened. Users can clear all history without affecting the
library.

------------------------------------------------------------------------

## 5. Reader

Open any imported chapter to enter the Reader.

The Reader provides:

-   Previous / Next chapter navigation
-   Bookmarks
-   Font size adjustment
-   Line spacing adjustment
-   Custom reading font import (`.ttf` / `.otf` from Files)

These features are provided by Monori across the supported sources.

### Previous / Next chapter

The bottom toolbar provides Previous Chapter and Next Chapter
navigation.

### Bookmarks

Tap the bookmark control in the Reader to bookmark the current chapter.

Bookmarks are stored locally on the device and may be included as
metadata in a manual iCloud backup.

### Font size and line spacing

Open the reading preferences panel using the T control in the Reader.

The following settings are available:

-   Font size
-   Line spacing

### Custom reading font

Navigate to Settings \> Appearance \> Reading Font.

From this screen:

1.  Tap Import Font to select a `.ttf` or `.otf` file from the Files
    app.
2.  The imported font is validated and stored locally in the app
    sandbox.
3.  Select an imported font to use it as the Reader body font.
4.  The Reader updates immediately without reloading the chapter.
5.  Swipe left on an imported font to delete it.

Font files are stored only on the device. They are not uploaded or
included in iCloud backups. Clearing library data does not remove
imported fonts.

The default font is Source Serif 4 with Noto Serif TC fallback for
Traditional Chinese.

------------------------------------------------------------------------

## 6. Chapter Update Checking

Collections can be marked as being followed.

For supported sources, Monori can check whether new chapters have
appeared.

### Patreon

Patreon currently supports automatic foreground checking for followed
collections. When a new chapter is detected, the collection and chapter
list can show update or unread indicators.

Automatic detection requires an actual new chapter to be published on
the source website. The App Review demo content is intentionally stable,
so App Review may not see a new-chapter notification during a normal
review session.

### Vocus, AO3, and AsianFanfics

These sources currently use manual **Check for Updates / 檢查新章節**
rather than automatic periodic checking.

### Google Docs

Google Docs is treated as a static document and does not support
chapter-update detection.

------------------------------------------------------------------------

## 7. Authentication and Third-Party Accounts

Monori does not have its own user account system and does not provide
Monori account creation.

For sources that require authentication, users sign in directly to the
corresponding third-party website inside the Browser. `WKWebView`
manages the website data and authentication session.

The following demo sources do not require login:

-   Vocus
-   AO3
-   AsianFanfics

The following demo sources require login:

-   Patreon
-   Google Docs

Both Patreon and Google Docs should be tested using the Google review
account provided in App Store Connect's App Review Information.

Any sign-up or account-management UI displayed inside Patreon or Google
belongs to that third-party website. Monori does not create, store,
manage, or delete those third-party accounts and has no technical or
administrative control over their account-deletion systems.

Monori does not enumerate, copy, or export authentication cookies,
sessions, tokens, or account credentials for use by a Monori service.

------------------------------------------------------------------------

## 8. Local Data, Network Architecture, and iCloud Backup

### Network architecture

Monori does not operate a backend or content proxy.

Website content is accessed directly through each website's own
infrastructure using `WKWebView`. Some importers use the existing
authenticated WebView session to request content for the local Reader.
These requests go directly to the relevant platform or resources
referenced by its pages and do not pass through a Monori server.

Monori does not attempt to bypass website authentication, membership, or
access controls.

### Local data

Depending on the source and import method, the local SwiftData library
may store:

-   Collection and chapter titles
-   Source and chapter URLs
-   Author information and visible date strings
-   Reading progress and reading status
-   Bookmarks
-   Reading preferences
-   Reading history
-   Imported chapter or document HTML where local content is required by
    the source

Patreon posts are read through the WebView and Monori does not provide
offline copies of Patreon posts.

### Manual iCloud backup

Monori provides manual iCloud backup and restore using the user's own
iCloud account through CloudKit's private database.

A backup may include:

-   Collection and chapter metadata
-   Bookmarks and reading progress
-   Reading history

A backup does **not** include:

-   Imported article or document HTML
-   Authentication cookies, sessions, or tokens
-   User account credentials
-   Reading preferences
-   Imported font files

The backup is a full snapshot, not continuous synchronization. Monori
does not provide automatic or real-time cross-device sync.

CloudKit communicates directly with the user's own iCloud account.
Backup data is not sent to a Monori server.

### Data deletion

Using **Clear Library Data / 清除書庫資料** deletes local library
metadata, reading history, and imported content stored by the app.

Logging out can clear the corresponding WebView website data and end
that website session.

An existing iCloud backup is not automatically deleted when local
Library data is cleared. Deleting the app removes local app data
according to iOS data-management behavior; an existing iCloud backup
remains in the user's iCloud account.

Monori does not provide:

-   A Monori account system
-   Cross-user content sharing or aggregation
-   A Monori-hosted cloud content library
-   A content proxy
-   A content export service
-   Third-party AI processing of imported content
-   Advertising or analytics services

Additional technical details are documented in `COMPLIANCE.md`.

------------------------------------------------------------------------

## 9. Testing Limitations

### Source websites may change

The supported websites control their own page layouts and authentication
flows.

A website layout or authentication change can temporarily affect the
Import button or Reader presentation.

### Chapter update detection

Update testing requires a new chapter to exist on the source website.

The demo content is intentionally stable, so this feature may not
produce an update indicator during App Review.

Patreon supports automatic foreground checking for followed collections.
Vocus, AO3, and AsianFanfics currently use manual update checking.
Google Docs does not support chapter-update detection.

### Login

Only Patreon and Google Docs require the App Review credentials supplied
in App Store Connect.

The other three demo sources can be tested without an account.

------------------------------------------------------------------------

## 10. Troubleshooting

### The Import button is not visible

Please make sure the exact demo page listed in this guide is open.

The Import control is context-sensitive and appears only when Monori
recognizes a supported page type.

### The page is still loading

Please wait for the website to finish loading before looking for the
Import control.

### Patreon or Google login is blocked

Please use the Google review account provided in App Store Connect's App
Review Information.

For Patreon, choose **Log in / Continue with Google**. It is not
necessary to create a new Patreon account.

If Google blocks the login because of the review location or requests
additional verification, please contact us through App Store Connect
messages. We can approve the login attempt or provide the required
verification code promptly.

### No new chapter notification appears

This is expected if no new chapter has been published since the last
check.

The demo content is intentionally stable. Monori does not simulate
new-chapter events for App Review.

------------------------------------------------------------------------

## 11. Feature Coverage

  Feature                                 Patreon   Vocus   AO3   Google Docs   AFF
  --------------------------------------- --------- ------- ----- ------------- -----
  Browse in Browser                       ✓         ✓       ✓     ✓             ✓
  Import                                  ✓         ✓       ✓     ✓             ✓
  Library                                 ✓         ✓       ✓     ✓             ✓
  Previous / Next chapter                 ✓         ✓       ✓     ✓             ✓
  Bookmarks                               ✓         ✓       ✓     ✓             ✓
  Font size                               ✓         ✓       ✓     ✓             ✓
  Line spacing                            ✓         ✓       ✓     ✓             ✓
  Automatic foreground chapter checking   ✓         ---     ---   ---           ---
  Manual chapter update checking          ✓         ✓       ✓     ---           ✓

------------------------------------------------------------------------

## 12. Contact

If App Review encounters a problem that is not covered by this guide,
please contact us through App Store Connect messages or at:

`hikarushane.dev@gmail.com`

Repository:

`https://github.com/hikarushane/monori`
