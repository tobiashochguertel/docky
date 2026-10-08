# Changelog

All notable changes to Docky are documented here. Version numbers are
assigned when a release is cut (see `scripts/release_sparkle_update.sh`
and git tags like `v0.9.4`); the Xcode project's `MARKETING_VERSION`
stays put between releases.

## [Unreleased]

### Added

- Layout snapshot now exports a `metrics` block with the sizing
  constants the inspector documents (icon↔label gap, label side inset,
  label row height, sideways label cap, folder chrome margin, chrome
  inset, mosaic / card / badge scales, indicator thickness, length and
  inset). The values are read from `TileLabelMetrics`,
  `TileLayoutMetrics` and the tile views themselves, so the inspector's
  "fixed vs configurable" table cannot drift from the code.
- Layout snapshot now exports **resolved, measured frames** per tile
  (`iconF`, `labelF`, `paintF` as `[x, y, w, h]` in tile-local points)
  plus the empty `bands` between them (`padTop`, `padGap`, `padBottom`,
  `insetL`, `insetR`, `labelGap`, `paintTop`, `paintL`). The inspector
  draws these directly instead of re-deriving the layout, so a doc
  figure cannot disagree with the running dock. `iconM`/`labelM`/`paintM`
  (sizes only) are still emitted for existing consumers.
- New `TileLayoutMetrics.chromeInset` names the widget-chrome inset
  (`floor(tileSize * 3/32)`) that `TileView` used to inline, and exports
  it in the snapshot. App tiles keep a zero inset; widget-chrome tiles
  (widget, smart stack, app tile showing a widget) reserve it.

- Optional iOS-style name labels for dock tiles and app folders. Two
  independent toggles (both default off) plus a shared label position
  (Below / Above / Leading / Trailing), text size slider, and optional
  custom text color under Settings → Appearance → Tile Layout. The dock
  toggle covers everything in the dock — app tiles, app-folder tiles,
  Launchpad, Start Menu, folders, Trash, and minimized windows; the
  folder toggle covers only the app names inside opened folders. Tiles
  grow to fit the label row — icons keep their full size — and every
  tile reserves the same row, so icon, indicator, and label rows stay
  aligned across apps, folders, and widgets. Both surfaces share the
  centralized `TileLabelView` / `TileLabeledContent` implementation.
- New profiles start as a copy of the active profile (tiles, widgets,
  and hidden apps) instead of empty.

### Fixed

- Dock preferences are no longer reseeded from the system Dock after
  the initial import, and apps grouped inside an app folder are no
  longer merged back as duplicate individual tiles. An intentionally
  emptied trailing section is preserved as-is.

### Internal

- `scripts/docky.py` (PEP 723) plus `mise.toml` tasks (`docky:build`,
  `docky:build-release`, `docky:deploy`, `docky:redeploy`, `docky:restart`,
  `docky:updates-on`) for local builds with a stable Developer ID
  identity, so macOS permissions survive rebuilds.
- Debug tooling: `DockyDebugService` writes diagnostics to
  `~/Library/Logs/Docky/docky-debug.log` (toggle live from
  Settings → Support → Debug or `docky.py debug`), per-tile geometry
  is logged on layout changes, and a technical X-ray overlay paints
  blue tile frames, green icon bounds, and yellow label bounds with a
  baseline guide over every tile, toggleable live or via a global
  shortcut (default ⌘⌥D, `docky.py overlay`). The layout is also
  snapshotted as machine-readable JSON (`docky-layout.json` next to
  the log, `docky.py layout`) for scripted inspection, consumed live
  by the standalone docky-inspector project (Bun + TypeScript browser
  UI with guides, history, and diffs).
