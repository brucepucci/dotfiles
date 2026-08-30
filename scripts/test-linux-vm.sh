#!/usr/bin/env bash
# test-linux-vm.sh — run the from-scratch test inside a clean Linux VM.
#
# Uses colima (a Lima Linux VM on this Mac) + a throwaway Debian 12
# container: nothing on this machine is touched, and the repo is mounted
# read-only. This exercises the "Linux" column of the README.
#
#   fast (default): scripts/smoke-test.sh against the pristine container
#                   userland — chezmoi apply (Ghostty's theme catalog
#                   fetched, pinned, exactly as CI does) + all shell
#                   behavior checks. ~1 min plus image pull on first run.
#
#   --full:         the actual new-machine bootstrap: Homebrew-on-Linux,
#                   brew bundle (neovim, language servers, wl-clipboard,
#                   xclip, node, pi via npm), then smoke-test.sh --nvim to
#                   restore plugins from lazy-lock.json. ~25 min, network
#                   heavy. This is as close to "fresh Linux box" as it gets
#                   short of real hardware.
#
# Usage:   scripts/test-linux-vm.sh [--full]
# Requires: colima (brew install colima). Starts the VM if stopped and
# stops it again afterwards ONLY if this script started it.

set -euo pipefail

SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FULL_FLAG=""
[[ "${1:-}" == "--full" ]] && FULL_FLAG="--full"

STARTED_VM=0
cleanup() {
  if [[ "$STARTED_VM" == 1 ]]; then
    echo "==> stopping colima (was started by this script)"
    colima stop >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

if ! colima status 2>/dev/null | grep -q 'running'; then
  echo "==> starting colima VM (first start takes a couple of minutes)"
  colima start
  STARTED_VM=1
fi
command -v docker >/dev/null || { echo "docker CLI not found (brew install docker)" >&2; exit 1; }

echo "==> running bootstrap test in debian:12 (repo mounted read-only)${FULL_FLAG:+ (full: brew bundle + plugins)}"
docker run --rm -i -v "$SOURCE":/src:ro debian:12 \
  bash -s -- $FULL_FLAG <<'SCRIPT'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq zsh curl ca-certificates sudo git python3 >/dev/null

# chezmoi from GitHub releases via the official .deb. Note: arm64 Linux
# has no uncompressed binary asset and the tarball naming is inconsistent
# between arches (linux_arm64 vs linux-glibc_amd64) -- the .deb is the one
# uniformly-named artifact, and this is a Debian container anyway.
arch=$(uname -m); case $arch in aarch64) arch=arm64;; x86_64) arch=amd64;; esac
ver=$(curl -fsSL https://api.github.com/repos/twpayne/chezmoi/releases/latest \
  | grep -oE '"tag_name": "v[0-9.]+"' | grep -oE '[0-9.]+')
curl -fsSL -o /tmp/chezmoi.deb \
  "https://github.com/twpayne/chezmoi/releases/download/v${ver}/chezmoi_${ver}_linux_${arch}.deb"
dpkg -i /tmp/chezmoi.deb
chezmoi --version

# Ghostty's theme catalog, same source and pin as CI (smoke.yml): every
# color-carrying template resolves its theme names at apply time via
# scripts/ghostty-theme.py, which reads Ghostty's bundled theme files.
# Ghostty has no headless Linux package, but its catalog is generated
# weekly from mbadolato/iTerm2-Color-Schemes -- same files, same names,
# same format. Keep ICS_SHA in lockstep with the workflow's pin.
ICS_SHA=752a9c079396cc9939b86e893578ed81e80c140f
git clone -q --depth 1 --filter=blob:none --sparse \
  https://github.com/mbadolato/iTerm2-Color-Schemes /tmp/ics
git -C /tmp/ics checkout -q --detach "$ICS_SHA"
git -C /tmp/ics sparse-checkout set ghostty
mv /tmp/ics/ghostty /tmp/ghostty-themes
export DOTFILES_GHOSTTY_THEMES=/tmp/ghostty-themes

if [[ "${1:-}" == "--full" ]]; then
  # Homebrew refuses to run as root -- do everything as a sudo-capable user.
  apt-get install -y -qq build-essential procps file >/dev/null
  useradd -m tester
  echo 'tester ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/tester
  su tester -c 'NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
  # README new-machine step 3, Linux branch of the Brewfile
  su tester -c 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" \
    && brew bundle --file /src/Brewfile'
  # steps 4 + full shell/plugin verification
  su tester -c '/src/scripts/smoke-test.sh --nvim'
else
  /src/scripts/smoke-test.sh
fi
SCRIPT

echo "==> PASS"
