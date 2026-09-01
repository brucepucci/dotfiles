# themes-local/ -- hand-written theme overrides

Files here override same-named files in `themes/` (the committed mirror):
scripts/theme.py reads this directory first, so a palette can be pinned or
hand-tuned without touching the mirror -- which scripts/themes-sync.sh
replaces wholesale, and would otherwise destroy the edit.

Same format as the mirror (Ghostty theme files: `palette = N=#hex` plus
`background`/`foreground`/cursor/selection keys). Never installed into
$HOME (chezmoiignored, like themes/ itself).
