# Monori App Review Guide

This guide is provided for App Review to explain how to test Monori's main features.

Monori is a local-first reading app. It allows users to browse content through supported websites and explicitly import accessible content into a local Library for reading.

Monori does not operate a backend server, content proxy, cloud library, or cross-user content service.

---

## 1. App Navigation

Monori has three main tabs:

| Tab          | Purpose                                         |
| ------------ | ----------------------------------------------- |
| **Browser**  | Browse supported websites and import content    |
| **Library**  | Read imported works and manage reading progress |
| **Settings** | Configure app and reading preferences           |

### Browser

The source selector at the top of the Browser tab provides five supported sources:

1. Patreon
2. Vocus
3. Archive of Our Own (AO3)
4. Google Docs
5. AsianFanfics (AFF)

Each source uses its own website session.

![Browser source selector](docs/app-review/screenshots/01-browser-source-selector.png)

---

# 2. Demo Content

The following works were created or uploaded by the developer specifically for App Review testing.

They are intended to provide predictable content without requiring reviewers to search for arbitrary third-party works.

| Source       | Login | Demo account / search  | Demo content        |
| ------------ | ----- | ---------------------- | ------------------- |
| Vocus        | No    | Search `hikaruHa`      | 「我在便利商店等一場雪」        |
| Patreon      | Yes   | Search `hikaruHa`      | 「霧港三號倉庫」            |
| AO3          | No    | Search `shane_y747`    | 「紙上幽靈」              |
| Google Docs  | Yes   | Shared with me         | 「鏽鐵之夏」              |
| AsianFanfics | No    | Search `monoriappdemo` | 「第十七次登出：一個沒有伺服器的世界」 |

The Patreon and Google Docs accounts require the credentials provided separately in App Store Connect's App Review Information.

---

# 3. Importing Content

The Import button appears only on supported page types.

For App Review testing, please use the demo content listed below.

## 3.1 Vocus

**Login required:** No

### Steps

1. Open **Browser**.
2. Select **Vocus** from the source selector.
3. Search for `hikaruHa`.
4. Open the room **「我在便利商店等一場雪」**.
5. The **Import / 匯入** button appears on the supported room page.
6. Tap **Import / 匯入**.

![Vocus demo room](docs/app-review/screenshots/02-vocus-demo.png)

The imported work will appear in the **Library** tab.

---

## 3.2 Patreon

**Login required:** Yes

### Steps

1. Open **Browser**.
2. Select **Patreon**.
3. Sign in using the App Review credentials provided in App Store Connect.
4. Search for `hikaruHa`.
5. Open the Collection **「霧港三號倉庫」**.
6. The **Import / 匯入** control is available on the Collection page.
7. Tap **Import / 匯入**.

![Patreon Collection](docs/app-review/screenshots/03-patreon-collection.png)

The Patreon demo content belongs to the developer's account.

The Collection page is the intended testing page for the Patreon importer.

---

## 3.3 Archive of Our Own (AO3)

**Login required:** No

### Steps

1. Open **Browser**.
2. Select **AO3**.
3. Search for `shane_y747`.
4. Open the work **「紙上幽靈」**.
5. The **Import / 匯入** control appears on the work page.
6. Tap **Import / 匯入**.

![AO3 demo work](docs/app-review/screenshots/04-ao3-demo.png)

No account is required for this demo work.

---

## 3.4 Google Docs

**Login required:** Yes

### Steps

1. Open **Browser**.
2. Select **Google Docs**.
3. Sign in using the App Review credentials provided in App Store Connect.
4. Open **Shared with me / 與我共享**.
5. Open the document **「鏽鐵之夏」**.
6. The **Import / 匯入** control appears in the supported document view.
7. Tap **Import / 匯入**.

![Google Docs demo document](docs/app-review/screenshots/05-google-docs-demo.png)

The document was created by the developer specifically for App Review testing.

Google Docs is treated as a static document. Automatic chapter-update detection is not available for this source.

---

## 3.5 AsianFanfics (AFF)

**Login required:** No

### Steps

1. Open **Browser**.
2. Select **AFF**.
3. Search for `monoriappdemo`.
4. Open the story **「第十七次登出：一個沒有伺服器的世界」**.
5. The **Import / 匯入** control appears on the supported story page.
6. Tap **Import / 匯入**.

![AsianFanfics demo story](docs/app-review/screenshots/06-aff-demo.png)

No account is required for this demo story.

---

# 4. Library

## 4.1 Import confirmation

After a successful import, Monori displays a confirmation message showing the number of imported chapters.

![Import confirmation](docs/app-review/screenshots/07-import-success.png)

When the same work is imported again, existing chapters are merged with the collection instead of creating duplicate chapters.

After importing a work, open the **Library** tab.

Imported works appear as collections in the user's local reading library.

![Library collection](docs/app-review/screenshots/08-library.png)

Tap a collection to view its chapters.

![Library chapter list](docs/app-review/screenshots/09-library-chapters.png)

The Library provides:

* Collection management
* Chapter navigation
* Reading progress
* Reading status
* Bookmarks
* Search and sorting
* Following / update checking for supported sources

---

## 5. Reader

Open any imported chapter to enter the Reader.

![Reader features](screenshots/10-reader-features.png)

The Reader provides the following features:

- Previous / Next chapter navigation
- Bookmarks
- Font size adjustment
- Line spacing adjustment

These features are provided by Monori and are available across the supported sources.

### Previous / Next chapter

The bottom toolbar provides **Previous Chapter** and **Next Chapter** navigation.

This navigation is available across all five supported sources.

### Bookmarks

Tap the bookmark control in the Reader to bookmark the current chapter.

Bookmarks are stored locally on the device.

### Font size and line spacing

Open the reading preferences panel using the **T** control in the Reader.

The following settings are available:

* Font size
* Line spacing

These reading preferences are provided by Monori and are available across all five supported sources.

---

# 6. Automatic Chapter Updates

Collections can be marked as being followed.

For supported dynamic sources, Monori can check whether new chapters have appeared.

When a new chapter is detected:

* The collection can show an update indicator.
* New chapters can receive an unread indicator.
* The chapter list can show a visual indication of new content.

Automatic update detection requires an actual new chapter to be published on the source website.

Therefore, App Review may not see a new-chapter notification during a normal review session because the developer's demo works are intentionally stable.

### Google Docs

Google Docs does not support automatic chapter-update detection.

A Google Docs document is treated as a static document rather than a continuously updated chapter-based source.

---

# 7. Authentication

Monori does not have its own user account system.

For sources that require authentication, the user signs in directly to the corresponding website inside the Browser.

The following demo sources do not require login:

* Vocus
* AO3
* AsianFanfics

The following demo sources require login:

* Patreon
* Google Docs

The required App Review credentials are provided separately through App Store Connect.

Monori does not ask the reviewer to create a Monori account.

---

# 8. Local Data and Network Architecture

Monori does not operate a backend server.

Website content is accessed directly through the website's own infrastructure using the WebView.

Monori does not act as a network proxy between the user and supported websites.

Depending on the source and import method, imported data may be stored locally on the device for the Library and Reader.

Local data may include:

* Collection titles
* Chapter titles
* Source URLs
* Author information
* Reading progress
* Reading status
* Bookmarks
* Reading preferences
* Imported chapter or document content where required by the source

This data is not uploaded to a Monori cloud service.

Monori does not provide:

* Cross-user content sharing
* Cloud content storage
* A content proxy
* A content export service
* Third-party AI processing of imported content
* A Monori account system

Additional technical details are documented in [COMPLIANCE.md](../COMPLIANCE.md).

---

# 9. Testing Limitations

### Source websites may change

The supported websites control their own page layouts and authentication flows.

A website layout or authentication change can temporarily affect the Import button or Reader presentation.

### Automatic update detection

Automatic update testing requires a new chapter to exist on the source website.

The demo content is intentionally stable, so this feature may not produce a notification during App Review.

### Google Docs

Google Docs is treated as a static source.

It supports importing and reading but does not support automatic chapter-update detection.

### Login

Only Patreon and Google Docs require the App Review credentials supplied in App Store Connect.

The other three demo sources can be tested without an account.

---

# 10. Troubleshooting

### The Import button is not visible

Please make sure the exact demo page listed in this guide is open.

The Import control is context-sensitive and appears only when Monori recognizes a supported page type.

### The page is still loading

Please wait for the website to finish loading before looking for the Import control.

### Patreon login does not work with Google

If the Google login option is unavailable inside Patreon, use the email/password credentials supplied for App Review if available.

This behavior depends on Google's authentication policies for embedded web environments.

### No new chapter notification appears

This is expected if no new chapter has been published since the last check.

Automatic update detection is not simulated by Monori.

---

# 11. Feature Coverage

| Feature                   | Patreon | Vocus | AO3 | Google Docs | AFF |
| ------------------------- | :-----: | :---: | :-: | :---------: | :-: |
| Browse in Browser         |    ✓    |   ✓   |  ✓  |      ✓      |  ✓  |
| Import                    |    ✓    |   ✓   |  ✓  |      ✓      |  ✓  |
| Library                   |    ✓    |   ✓   |  ✓  |      ✓      |  ✓  |
| Previous / Next chapter   |    ✓    |   ✓   |  ✓  |      ✓      |  ✓  |
| Bookmarks                 |    ✓    |   ✓   |  ✓  |      ✓      |  ✓  |
| Font size                 |    ✓    |   ✓   |  ✓  |      ✓      |  ✓  |
| Line spacing              |    ✓    |   ✓   |  ✓  |      ✓      |  ✓  |
| Automatic chapter updates |    ✓    |   ✓   |  ✓  |      —      |  ✓  |

---

## 12. Contact

If App Review encounters a problem that is not covered by this guide, please use the contact information provided in App Store Connect.

Repository:

https://github.com/hikarushane/monori
