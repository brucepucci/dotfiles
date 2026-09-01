#!/usr/bin/env bash
# themes-sync.sh -- refresh themes/ from the upstream color catalog.
#
# themes/ is a committed mirror of the ghostty/ directory of
# mbadolato/iTerm2-Color-Schemes -- the palette source of truth for every
# color this repo renders (see docs/theming.md). The mirror ships with the
# repo so `chezmoi apply` needs no Ghostty install and reads nothing but
# local files; this script is the only way it updates, run BY HAND when you
# want newer upstream themes:
#
#   scripts/themes-sync.sh          # mirror upstream, bump SOURCE.md's block
#
# Never called by chezmoi, the smoke test, or CI. The commit it produces is
# reviewable like any other change; themes/SOURCE.md records the exact
# upstream SHA mirrored, so `git log -p themes/SOURCE.md` is the mirror's
# history. The sync rewrites ONLY the metadata block between SOURCE.md's
# <!-- synced:... --> markers -- the prose around it is hand-maintained.
#
# Hand-written theme overrides do NOT live in themes/ (this script replaces
# it wholesale); they live in themes-local/, which the resolver searches
# first and this script never touches.
#
# macOS only (bsdtar); stdlib tools only.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPSTREAM_URL="https://github.com/mbadolato/iTerm2-Color-Schemes"
UPSTREAM_GIT="https://github.com/mbadolato/iTerm2-Color-Schemes.git"
MIN_FILES=500   # sanity gate: the catalog has 600+ theme files; far fewer
                # means the extraction matched the wrong tree -- refuse

die() { printf 'themes-sync: %s\n' "$1" >&2; exit 1; }

command -v git     >/dev/null || die "git not found"
command -v curl    >/dev/null || die "curl not found"
command -v tar     >/dev/null || die "tar not found"
command -v python3 >/dev/null || die "python3 not found"

# Resolve the SHA FIRST, then fetch that exact SHA, so SOURCE.md cannot lie
# about what was mirrored (the default branch may move between the two
# requests). HEAD follows whatever the default branch is, however upstream
# renames it.
sha="$(git ls-remote "$UPSTREAM_GIT" HEAD | cut -f1)"
[[ "$sha" =~ ^[0-9a-f]{40}$ ]] || die "could not resolve upstream HEAD SHA (got: '$sha')"
echo "upstream HEAD: $sha"

# Stage INSIDE the repo so the final swap is a same-filesystem rename: a
# cross-filesystem mv is a copy that can die halfway, and $TMPDIR is
# frequently a different volume than the repo.
stage="$(mktemp -d "$REPO/.themes-sync.XXXXXX")"
old=""
cleanup() {
  [[ -z "$stage" ]] || rm -rf "$stage"
  [[ -z "$old"   ]] || rm -rf "$old"
  return 0
}
trap cleanup EXIT
chmod 755 "$stage"   # mktemp creates 0700; the mirror must stay world-readable

curl -fsSL "https://codeload.github.com/mbadolato/iTerm2-Color-Schemes/tar.gz/$sha" \
  | tar -xz -C "$stage" --strip-components=2 '*/ghostty/*' \
  || die "download/extract failed"

# tar's include pattern matches path SEGMENTS, not only upstream's top-level
# ghostty/ directory -- tools/templates/ghostty once rode in as templates/.
# A theme is exactly a top-level regular file: prune everything else.
find "$stage" -mindepth 1 -maxdepth 1 ! -type f -exec rm -rf {} +

# Count FILES, not directory entries (see above for the stray dir that
# once inflated this and the MIN_FILES gate).
count="$(find "$stage" -maxdepth 1 -type f | wc -l | tr -d ' ')"
[[ "$count" -ge "$MIN_FILES" ]] \
  || die "extracted only $count theme files (< $MIN_FILES) -- not replacing the mirror"

# Swap with a rollback: themes/ is never absent-or-half-copied. If anything
# between the two renames fails, the trap removes the staging dir and the
# old mirror is still one rename away.
old="$REPO/.themes-old.$$"
mv "$REPO/themes" "$old"
mv "$stage" "$REPO/themes"
stage=""   # moved: the trap must not rm the new mirror
rm -rf "$old"; old=""

# SOURCE.md: rewrite only the metadata block between the synced markers;
# everything else in the file (divergence notes, override docs) is
# hand-maintained and must survive the sync.
src="$REPO/themes/SOURCE.md"
meta="- mirrored from: $UPSTREAM_URL (ghostty/ directory)
- upstream commit: \`$sha\`
- mirrored on: $(date +%Y-%m-%d)
- files: $count"
if [[ ! -f "$src" ]]; then
  die "themes/SOURCE.md is missing -- restore it from git before syncing"
fi
python3 - "$src" "$meta" <<'PY'
import sys
path, meta = sys.argv[1], sys.argv[2]
BEGIN, END = "<!-- synced:begin -->", "<!-- synced:end -->"
text = open(path).read()
try:
    i, j = text.index(BEGIN) + len(BEGIN), text.index(END)
except ValueError:
    sys.exit("themes-sync: SOURCE.md lost its synced markers -- fix by hand")
open(path, "w").write(text[:i] + "\n" + meta + "\n" + text[j:])
PY

echo "mirrored $count theme files -> $REPO/themes (SOURCE.md block updated)"
git -C "$REPO" status --short -- themes/ | head -3
echo "review with: git diff --stat themes/"
