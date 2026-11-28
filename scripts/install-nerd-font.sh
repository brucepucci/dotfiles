#!/usr/bin/env bash
# install-nerd-font.sh -- JetBrainsMono Nerd Font, on Linux.
#
# On macOS the font is a Homebrew cask and the Brewfile handles it. Homebrew
# has no casks on Linux, and the font is not packaged by Fedora, so this
# script is the Linux half of that Brewfile line: download the release
# archive from nerd-fonts and unpack it into the per-user font directory.
#
#   scripts/install-nerd-font.sh
#
# Idempotent: an already-installed font is left alone (pass --force to
# reinstall). Run BY HAND, like scripts/themes-sync.sh -- never by chezmoi,
# because it reaches the network.
#
# Why it is needed: the zsh prompt's git branch mark and Neovim's
# diagnostic + markdown icons are Nerd Font glyphs. Bazzite ships
# "Symbols Nerd Font", which covers the glyphs but not the monospace text
# face, and Ptyxis will not fall back for a font it was never given.

set -euo pipefail

FONT="JetBrainsMono"
VERSION="${NERD_FONT_VERSION:-v3.4.0}"
DEST="${XDG_DATA_HOME:-$HOME/.local/share}/fonts"
URL="https://github.com/ryanoasis/nerd-fonts/releases/download/$VERSION/$FONT.tar.xz"

die() { printf 'install-nerd-font: %s\n' "$1" >&2; exit 1; }

force=0
[ "${1:-}" = "--force" ] && force=1

command -v curl >/dev/null || die "curl not found"
command -v tar  >/dev/null || die "tar not found"

if (( ! force )) && fc-list 2>/dev/null | grep -i "$FONT Nerd Font" >/dev/null; then
  echo "$FONT Nerd Font is already installed (--force to reinstall)"
  exit 0
fi

mkdir -p "$DEST/$FONT"
# Stage in a temp dir: a half-extracted archive directly into the font
# directory would leave fontconfig indexing broken files.
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT

echo "downloading $FONT Nerd Font $VERSION"
curl -fsSL "$URL" | tar -xJ -C "$stage" || die "download/extract failed ($URL)"

# The archive carries the licenses and a README alongside the faces; only
# the fonts belong in the font path.
find "$stage" -maxdepth 1 -type f \( -name '*.ttf' -o -name '*.otf' \) \
  -exec cp {} "$DEST/$FONT/" \;

count="$(find "$DEST/$FONT" -type f \( -name '*.ttf' -o -name '*.otf' \) | wc -l | tr -d ' ')"
[ "$count" -gt 0 ] || die "no font files extracted -- the release layout may have changed"

if command -v fc-cache >/dev/null; then
  fc-cache -f "$DEST" >/dev/null
fi

echo "installed $count faces -> $DEST/$FONT"
echo "select it with Ptyxis > Preferences > Font (or install it before the first chezmoi apply)"
