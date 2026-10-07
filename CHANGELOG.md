# Changelog

All notable changes to Docky are documented here. Version numbers are
assigned when a release is cut (see `scripts/release_sparkle_update.sh`
and git tags like `v0.9.4`); the Xcode project's `MARKETING_VERSION`
stays put between releases.

## [Unreleased]

### Added

- Optional iOS-style name labels for dock tiles and app folders. Two
  independent toggles (both default off) plus a shared label position
  (Below / Above / Leading / Trailing) under Settings → Appearance →
  Tile Layout. The dock toggle covers app tiles as well as Launchpad,
  Start Menu, folder, Trash, and minimized-window tiles; the folder
  toggle covers the folder's own dock tile and the app names inside
  opened folder popovers. Both surfaces share the centralized
  `TileLabelView` / `TileLabeledContent` implementation.
- New profiles start as a copy of the active profile (tiles, widgets,
  and hidden apps) instead of empty.

### Fixed

- Dock preferences are no longer reseeded from the system Dock after
  the initial import, and apps grouped inside an app folder are no
  longer merged back as duplicate individual tiles. An intentionally
  emptied trailing section is preserved as-is.

### Internal

- `scripts/docky.py` (PEP 723) plus `mise.toml` tasks (`docky:build`,
  `docky:build-release`, `docky:deploy`, `docky:redeploy`,
  `docky:updates-on`) for local builds with a stable Developer ID
  identity, so macOS permissions survive rebuilds.
