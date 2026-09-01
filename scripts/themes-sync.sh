#!/usr/bin/env bash
# themes-sync.sh -- refresh themes/ from the upstream color catalog.
#
# themes/ is a committed mirror of the ghostty/ directory of
# mbadolato/iTerm2-Color-Schemes -- the palette source of truth for every
# color this repo renders (see docs/theming.md). The mirror ships with the
# repo so `chezmoi apply` needs no network and no Ghostty install; this
# script is the only way it updates, run BY HAND when you want newer
# upstream themes:
#
#   scripts/themes-sync.sh          # mirror upstream master, rewrite SOURCE.md
#
# Never called by chezmoi, the smoke test, or CI. The commit it produces is
# reviewable like any other change; themes/SOURCE.md records the exact
# upstream SHA mirrored, so `git log -p themes/SOURCE.md` is the mirror's
# history.
#
# macOS only (bsdtar); stdlib tools only.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPSTREAM_URL="https://github.com/mbadolato/iTerm2-Color-Schemes"
UPSTREAM_GIT="https://github.com/mbadolato/iTerm2-Color-Schemes.git"
MIN_FILES=500   # sanity gate: the catalog has 600+ files; far fewer means
                # the extraction matched the wrong tree -- refuse to replace

die() { printf 'themes-sync: %s\n' "$1" >&2; exit 1; }

command -v git   >/dev/null || die "git not found"
command -v curl  >/dev/null || die "curl not found"
command -v tar   >/dev/null || die "tar not found"

# Resolve the SHA FIRST, then fetch that exact SHA, so SOURCE.md cannot lie
# about what was mirrored (master may move between the two requests).
sha="$(git ls-remote "$UPSTREAM_GIT" master | cut -f1)"
[[ "$sha" =~ ^[0-9a-f]{40}$ ]] || die "could not resolve upstream master SHA (got: $sha)"
echo "upstream master: $sha"

tmp="$(mktemp -d "${TMPDIR:-/tmp}/themes-sync.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

curl -fsSL "https://codeload.github.com/mbadolato/iTerm2-Color-Schemes/tar.gz/$sha" \
  | tar -xz -C "$tmp" --strip-components=2 '*/ghostty/*' \
  || die "download/extract failed"

count="$(ls -1 "$tmp" | wc -l | tr -d ' ')"
[[ "$count" -ge "$MIN_FILES" ]] \
  || die "extracted only $count files (< $MIN_FILES) -- not replacing the mirror"

# Wholesale replace: the mirror is always an exact copy of upstream ghostty/,
# never a mix of two snapshots.
rm -rf "$REPO/themes"
mv "$tmp" "$REPO/themes"

date="$(date +%Y-%m-%d)"
cat > "$REPO/themes/SOURCE.md" <<EOF
# themes/ -- the palette mirror

Every file here is a verbatim copy of the \`ghostty/\` directory of
[mbadolato/iTerm2-Color-Schemes]($UPSTREAM_URL) at the commit below -- the
root of this repo's color system (docs/theming.md). Names are filenames;
settings.toml's light_theme/dark_theme resolve against them via
scripts/theme.py. Refresh with scripts/themes-sync.sh.

- mirrored from: $UPSTREAM_URL (ghostty/ directory)
- upstream commit: \`$sha\`
- mirrored on: $date
- files: $count
- license: MIT, (c) 2011-present Mark Badolato -- see the upstream repo

## Known divergences from Ghostty's bundled catalog

Upstream's ghostty/ and the catalog Ghostty ships in its app bundle are
siblings, not copies. When this mirror was first vendored, 455 of Ghostty's
463 names were byte-identical; these 8 differ (upstream is newer or the
maintainers diverged) -- none are this repo's active themes:

- Catppuccin Frappe, Catppuccin Latte, Catppuccin Macchiato, Catppuccin Mocha
- Adwaita, Adwaita Dark
- Cursor Dark
- Electron Highlighter

If one of these ever matters, drop a hand-written file in themes/ with the
same name to override it -- the resolver reads the local file either way.
This list was captured by hand at first vendor; it is informational, not
checked by anything.
EOF

echo "mirrored $count files -> $REPO/themes (SOURCE.md updated)"
git -C "$REPO" status --short -- themes/ | head -3
echo "review with: git diff --stat themes/"
