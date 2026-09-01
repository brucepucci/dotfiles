# themes/ -- the palette mirror

Every file here is a verbatim copy of the `ghostty/` directory of
[mbadolato/iTerm2-Color-Schemes](https://github.com/mbadolato/iTerm2-Color-Schemes) at the commit below -- the
root of this repo's color system (docs/theming.md). Names are filenames;
settings.toml's light_theme/dark_theme resolve against them via
scripts/theme.py. Refresh with scripts/themes-sync.sh, which rewrites only
the block between the `synced` markers below -- the rest of this file is
hand-maintained.

<!-- synced:begin -->
- mirrored from: https://github.com/mbadolato/iTerm2-Color-Schemes (ghostty/ directory)
- upstream commit: `752a9c079396cc9939b86e893578ed81e80c140f`
- mirrored on: 2026-09-01
- files: 607
<!-- synced:end -->
- license: MIT, (c) 2011-present Mark Badolato -- see the upstream repo

## Overriding a theme

The sync replaces this directory wholesale, so hand-written palettes do
not live here: drop the file in `themes-local/` (repo root, chezmoiignored,
never touched by the sync) with the same name, and the resolver reads it
first. `DOTFILES_THEMES` (tests) still overrides everything.

## Known divergences from Ghostty's bundled catalog

Upstream's ghostty/ and the catalog Ghostty ships in its app bundle are
siblings, not copies. When this mirror was first vendored, 455 of Ghostty's
463 names were byte-identical; these 8 differ (upstream is newer or the
maintainers diverged) -- none are this repo's active themes:

- Catppuccin Frappe, Catppuccin Latte, Catppuccin Macchiato, Catppuccin Mocha
- Adwaita, Adwaita Dark
- Cursor Dark
- Electron Highlighter

This list was captured by hand at first vendor and is informational, not
checked by anything.
