#!/usr/bin/env bash
# =============================================================================
# scripts/packages-macos.sh
# macOS packages via Homebrew (see ../Brewfile). Idempotent.
# Called by ../install.sh; config files, shell plugins and Neovim plugins are handled there.
# =============================================================================
set -Eeuo pipefail

log() { printf '\033[0;32m[info]\033[0m  %s\n' "$*"; }
warn() { printf '\033[0;33m[warn]\033[0m  %s\n' "$*"; }
has() { command -v "$1" >/dev/null 2>&1; }

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Command Line Tools provide git, clang and make
if ! xcode-select -p >/dev/null 2>&1; then
  log "Installing the Xcode Command Line Tools (a dialog will open; re-run this script afterwards)..."
  xcode-select --install || true
  exit 1
fi

# Homebrew
if ! has brew; then
  log "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)" # Apple Silicon
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)" # Intel
fi

log "Installing Brewfile packages..."
brew bundle --file "$REPO/Brewfile"

# Rust toolchain (rustup is keg-only in Homebrew; it installs into ~/.cargo)
export PATH="$HOME/.cargo/bin:$PATH"
if ! has cargo; then
  log "Installing the Rust toolchain..."
  "$(brew --prefix rustup)/bin/rustup-init" -y --no-modify-path
fi
rustup component add rustfmt clippy rust-src rust-analyzer 2>/dev/null || true

# Python tools (same set as on Ubuntu)
export PATH="$HOME/.local/bin:$PATH"
for tool in ruff basedpyright pre-commit; do
  uv tool install "$tool" >/dev/null 2>&1 || true
done

log "Packages done."
