# Monori Compliance Notes

## What Monori is

Monori is a local-first iOS reading app for content the user can already access through supported web services. It supports Patreon, Google Docs, AO3, Vocus, and AsianFanfics.

The app has no Monori backend, account system, analytics service, advertising service, or cross-user content service. Web content is accessed from the corresponding provider through `WKWebView` or, for supported import flows, through requests made from the authenticated web session already open in the WebView.

Monori does not provide a separate content-hosting service. It does not proxy provider traffic through a Monori server.

## Source-specific behavior

### Patreon

* The user signs in to their own Patreon account inside the app's WebView.
* Patreon serves the pages and enforces its own authentication and access controls.
* Monori does not use Patreon's official or internal API.
* The collection importer reads chapter links and metadata from the Patreon page already displayed in the WebView.
* Patreon post content is read through the WebView rather than downloaded to a Monori server.
* Reading progress, bookmarks, collection metadata, and chapter links are stored locally on the device.
* Monori does not provide offline copies of Patreon posts.

### Google Docs

* The user opens Google Docs/Drive through the WebView using their own Google session.
* The importer requests the document's mobile HTML from the authenticated page context when the user explicitly imports a document.
* Imported document HTML may be stored locally as part of the local library so the reader can display the imported document without keeping the source page open.
* The document is not uploaded to a Monori server because no such backend exists.
* Monori does not obtain or export Google account cookies to an external service.

### AO3

* The user accesses Archive of Our Own through the WebView.
* Chapter and navigation pages are requested from AO3 using the user's existing WebView session where authentication is required.
* Imported chapter HTML may be stored locally as part of the local library.
* Monori does not upload AO3 content to a Monori server and does not provide a cross-user content repository.
* Monori does not use an AO3 API as a backend service.

### Vocus

* The user accesses Vocus through the WebView.
* Monori detects supported Vocus room/article pages from the page currently loaded in the WebView and uses the site's own URLs for navigation.
* Imported content may be stored locally as part of the local library where the corresponding importer provides HTML content.
* No Vocus content is sent to a Monori server.
* Monori does not operate a Vocus content mirror or shared repository.

### AsianFanfics

* The user accesses AsianFanfics through the WebView.
* Supported story pages are detected and displayed through the app's reading interface.
* The app applies local content-blocking rules to supported advertising and tracking resources on AsianFanfics pages. These rules run locally in WebKit; they do not route traffic through a Monori server.
* Imported content may be stored locally as part of the local library where the corresponding importer provides HTML content.
* No AsianFanfics content is sent to a Monori server.

## Authentication and website data

* Monori does not enumerate, copy, export, or transmit authentication cookies to its own services.
* `WKWebView` manages website data and authentication sessions for the supported providers.
* The app can clear the WebView website data on logout.
* A provider remains responsible for its own authentication and access control. Monori does not attempt to bypass those controls.

## Network architecture

Monori has no backend proxy. Provider requests made by the WebView go to the provider or to resources referenced by the provider's pages. Monori does not place a Monori server between the user and the supported website.

Some importers make authenticated requests from the page context to retrieve content for the local reader. Those requests use the existing WebView session and are not routed through a Monori backend.

Monori does not intercept arbitrary WebView network responses.

## What Monori does not provide

* No Monori backend or cloud storage.
* No cross-user sharing or aggregation of imported content.
* No upload of imported chapter/document content to Monori infrastructure.
* No content analytics, advertising analytics, or AI service receiving imported content.
* No export feature for imported content.
* No provider API credentials managed by Monori.
* No mechanism intended to bypass provider authentication or membership/access controls.

## What is stored locally

Depending on the source and import flow, the local SwiftData library can store:

* Collection and chapter titles.
* Source URLs and chapter URLs.
* Creator names and visible date strings where available.
* Reading status, ordering, reading progress, and bookmarks.
* Font and reading preferences.
* Imported chapter/document HTML when a source importer needs local content for the reader.

This data is local application data. Monori does not sync it to a Monori cloud service.

## Data deletion

* **Clear Library Data** deletes the local library metadata and imported local content stored by the app.
* **Logout** can clear the WebView website data store and end the corresponding website session.
* Deleting the app removes its local application data according to iOS data management behavior.

## Access revocation

For WebView-based reading, the provider remains the source of truth for access. If access is revoked, Monori does not have a Monori-hosted copy that can be used to restore access.

For sources that support local import, previously imported content can remain in the device's local library until the user deletes it. Monori does not claim that deleting access at the provider automatically deletes a copy that the user previously chose to import locally.

## App Store and platform-policy risk

Monori is intended for distribution through the App Store. App Store review is separate from the technical network architecture described above.

Apple's review rules require apps that primarily provide web content to offer sufficient app-specific functionality. Monori therefore relies on native library management, reading progress, bookmarks, chapter navigation, reading preferences, source handling, and import workflows in addition to WebView rendering. Whether the resulting feature set satisfies App Store Review is an Apple review decision, not something this document can guarantee.

## Provider terms and policy risk

Monori's technical behavior does not by itself establish that every supported provider permits every use case. Provider Terms of Service, acceptable-use rules, copyright policies, authentication rules, and changes to site behavior may impose additional restrictions.

At present, the project treats this as a policy/compliance risk rather than claiming that the providers explicitly endorse Monori. The project does not claim affiliation with Patreon, Google, AO3, Vocus, or AsianFanfics.

The supported providers can also change their markup, authentication flows, anti-bot measures, APIs, or terms. Such changes may break an importer or make a particular workflow unavailable without changing the app's local-only network architecture.

## Engineering boundaries

The following boundaries are intentional and should not be removed without a separate compliance review:

* No backend or content proxy.
* No cookie extraction or credential export.
* No provider API keys or private provider credentials embedded in the app.
* No cross-user content service.
* No upload of imported content to third-party analytics, AI, or storage services.
* No feature whose purpose is to bypass provider access controls.
