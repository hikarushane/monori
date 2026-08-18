# Design System: Monori

> Single source of truth for Monori's visual language. Monori is a SwiftUI iOS
> reading shell, so this document is expressed in SwiftUI/UIKit terms (not
> Tailwind/web). It encodes the rules from `design-taste-frontend` and
> `stitch-design-taste`, adapted to a native iOS app. When you add a screen,
> source, or icon, conform to this.

## 1. Visual Theme & Atmosphere

Calm, gallery-airy reading utility. **Density 3** (airy), **Variance 3**
(predictable, content-first), **Motion 4** (restrained, purposeful). The chrome
recedes so imported prose is the subject; the only personality lives in a single
sage accent and a small family of hand-drawn geometric icons. Think "quiet
private library", not "media app".

## 2. Color Palette & Roles

The canonical palette is **Uguisu Zen** —
[`docs/design/.../uguisu_zen/DESIGN.md`](docs/design/stitch_monori_app_icon_identity/uguisu_zen/DESIGN.md)
holds the full token set. Only the color layer of that system applies here;
its web typography does not (see §3). Named tokens below are the ones Monori
actually uses — quote these hexes, not ad-hoc ones.

| Token | Hex | Lives in | Role |
| --- | --- | --- | --- |
| `uguisu-iro` | `#A8B9A0` | `BrandSage` colorset, app icon, App Store showcase | App-icon ground, launch screen, large brand surfaces |
| `primary` | `#53634E` | — (see delta below) | Selected tab, active controls, bookmarks, loading-bar fill, primary buttons |
| `on-surface` | `#1B1C1C` | showcase headline + logo mark | Primary text / filled icon marks on light surfaces |
| `sumi-ink` | `#1A1A1A` | — | Reading body ink at maximum legibility |
| `charcoal` | `#333333` | `monori_icon_charcoal` | UI chrome and secondary text |
| `washi-white` | `#F9F9F7` | showcase light shapes | Paper ground — the substitute for pure `#FFFFFF` |
| `surface` | `#FBF9F8` | — | Light canvas |
| `outline-variant` | `#C4C8BF` | — | Hairline dividers |
| `error` | `#BA1A1A` | — | Destructive actions only |

Everything else stays system-driven: **System Secondary** for metadata and
unselected icons (`.foregroundStyle(.secondary)`), **system background / `.bar`**
for surfaces and the source picker / tab bar.

**Known deltas between the tokens and shipped code** (documented, not silently
reconciled — closing either one repaints the app):

- `AccentColor.colorset` ships `#5C7150` (RGB 0.361/0.443/0.314), while the
  Uguisu Zen `primary` token is `#53634E`.
- The three reader rulesets (`ReaderRuleset.css`, `AFFReaderRuleset.css`,
  `VocusReaderRuleset.css`) paint the dark-mode body `#1c1b19`; the matching
  token is `on-surface` `#1B1C1C`.

Rules: exactly **one** accent (sage). No second accent anywhere — a sage app
never grows a blue CTA or a teal badge. No rainbow gradients (Patreon's own
gradient loading bar is actively suppressed; see `SuppressLoadingBar.js`). Never
pure black, and never pure white — use `on-surface` and `washi-white`. Respect
dark mode via system colors.

## 3. Typography

System font (San Francisco) throughout, weight- and color-driven hierarchy:
titles `.headline`, metadata `.subheadline`/`.caption` in secondary. Reader body
size and line-height are user-controlled (`ReaderPreferences`). Chinese UI copy
is Traditional (繁體中文). No custom font bundling; no serif for UI chrome.
Uguisu Zen names Manrope and Source Serif 4; Monori deliberately does not adopt
them — a native iOS shell should read as San Francisco.

## 4. Icon System (the core of this document)

**Every source icon and bottom-navigator icon is a hand-drawn geometric
`Shape`, never an SF Symbol.** They are constructed from primitives — rounded
bars, circles, triangles, hairlines — so the whole set reads as one family and
tints to the sage accent. All marks live in
[`App/Features/Shared/MonoriIcons.swift`](App/Features/Shared/MonoriIcons.swift).

**Construction rules**

- Draw in a normalized 0…1 box (`rect.width`/`rect.height` fractions) so a mark
  scales cleanly from a 16pt picker chip to a 27pt tab glyph.
- Two finishes only: **filled** (solid silhouette, e.g. `PatreonMark`,
  `LibraryBooks`) or **outlined** (`stroke` ~1.5–1.8pt, round joins, e.g.
  `DriveMark`, `BrowseGlobe`, `SettingsSliders`). Pick whichever reads best at
  16pt; mixing the two finishes across the set is expected and fine.
- Render with the current foreground style (`.fill(.foreground)` /
  `.stroke(.foreground, …)`) so callers tint via `.foregroundStyle(...)` and
  selection state comes for free.

**Source icons** — one shared component, `SourceGlyph(kind:)`, is the single
source of truth. It is used by **both** the Browse source picker and the Library
collection list, so the two can never drift. Current marks: `.patreon` →
`PatreonMark` (filled bar + circle, a pared-down "P"); `.googleDocs` →
`DriveMark` (outlined triangle).

**Bottom navigator** — `MonoriTabIcon` rasterizes three glyphs to template
images for `TabView.tabItem`: `BrowseGlobe` (circle + meridian + equator),
`LibraryBooks` (three filled spines — the app-icon motif), `SettingsSliders`
(two control sliders).

### Adding a new source (do this every time)

1. Draw `NewSourceMark: Shape` in `MonoriIcons.swift` in the style above.
2. Add a `case` to `SourceGlyph` mapping the new `SourceKind` to that mark.
3. Done — it appears in the Browse picker and the Library list automatically.
   **Do not** render a user-facing source icon from `SourceProvider.iconSystemName`;
   that field is a non-UI fallback only.

## 5. Component Stylings

- **Buttons:** `.bordered` / `.borderedProminent`, sage tint, system tactile
  press. No gl:ow, no custom shadows.
- **Lists/Cards:** plain lists with hairline dividers and negative space over
  heavy cards (density is low). Collection rows: source glyph + title + metadata.
- **Loading:** a single linear `ProgressView` tinted sage at the top of Browse.
  The page's own loading bars are suppressed so the brand bar is the only one.
- **Empty states:** `ContentUnavailableView` with a short instruction, no art.

## 6. Motion & Interaction

Restrained. 0.15–0.3s ease for chrome toggles, source cross-fade, chapter-swipe
indicators. Animate `opacity`/`transform` only. No perpetual/looping animation.
Haptic on chapter-boundary activation.

## 7. Anti-Patterns (Banned)

- **No SF Symbols for source or navigator icons** — always a `Shape` from
  `MonoriIcons.swift`.
- No second accent color; no purple/neon; no rainbow gradients.
- No pure black; no serif UI chrome; no bundled display fonts.
- No emoji in UI copy.
- No source icon rendered from `iconSystemName` in a user-facing view.
- No drift between the Browse picker and the Library list — both use `SourceGlyph`.
