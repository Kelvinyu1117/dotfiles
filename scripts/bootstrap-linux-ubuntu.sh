#!/usr/bin/env bash
# =============================================================================
# scripts/bootstrap-linux-ubuntu.sh
# OrbStack / Ubuntu dev VM bootstrap — idempotent, chezmoi-first
# Usage: bash scripts/bootstrap-linux-ubuntu.sh
# =============================================================================
set -Eeuo pipefail

# ── helpers ───────────────────────────────────────────────────────────────────
log()  { printf '\033[0;32m[info]\033[0m  %s\n' "$*"; }
warn() { printf '\033[0;33m[warn]\033[0m  %s\n' "$*"; }
die()  { printf '\033[0;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }
has()  { command -v "$1" >/dev/null 2>&1; }

# ── paths ─────────────────────────────────────────────────────────────────────
USER_BIN="$HOME/.local/bin"
mkdir -p "$USER_BIN"
export PATH="$USER_BIN:$HOME/.cargo/bin:$HOME/.local/share/uv/tools/bin:$PATH"

# ── arch ──────────────────────────────────────────────────────────────────────
case "$(uname -m)" in
  x86_64|amd64)  ARCH_ID="x86_64" ;;
  aarch64|arm64) ARCH_ID="arm64"  ;;
  *) die "unsupported architecture: $(uname -m)" ;;
esac
NVIM_ARCH="$ARCH_ID"
LAZYGIT_ARCH="$ARCH_ID"
YAZI_ARCH="${ARCH_ID/arm64/aarch64}"   # yazi uses aarch64, not arm64

# =============================================================================
# 1. APT PACKAGES
# =============================================================================
log "Installing apt packages..."
sudo apt-get update -q
sudo apt-get install -y -q --no-install-recommends \
  build-essential pkg-config autoconf automake libtool \
  git curl wget ca-certificates gnupg lsb-release software-properties-common \
  zsh tmux unzip zip tar xz-utils file tree jq htop \
  openssh-client rsync \
  ripgrep bat fzf eza fd-find \
  shellcheck \
  python3 python3-dev python3-venv python3-pip pipx \
  cmake ninja-build ccache gdb valgrind \
  clang clangd clang-format clang-tidy \
  lldb llvm lld libc++-dev libc++abi-dev \
  libssl-dev zlib1g-dev libbz2-dev libreadline-dev \
  libsqlite3-dev libffi-dev liblzma-dev libncursesw5-dev uuid-dev

# Ubuntu renames these — create canonical symlinks
ln -sf "$(command -v fdfind 2>/dev/null || true)" "$USER_BIN/fd"  2>/dev/null || true
ln -sf "$(command -v batcat 2>/dev/null || true)" "$USER_BIN/bat" 2>/dev/null || true

# =============================================================================
# 2. RUST + CARGO TOOLS
# =============================================================================
if ! has rustup; then
  log "Installing Rust..."
  curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs \
    | sh -s -- -y --profile default --default-toolchain stable --no-modify-path
fi

export PATH="$HOME/.cargo/bin:$PATH"
rustup update stable 2>/dev/null || true
rustup component add rustfmt clippy rust-src rust-analyzer 2>/dev/null || true

# cargo-binstall: download prebuilt binaries, falls back to compile
if ! has cargo-binstall; then
  log "Installing cargo-binstall..."
  curl -L --proto '=https' --tlsv1.2 -sSf \
    https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh \
    | bash
fi

# sccache: activate as compiler cache before remaining cargo installs
if ! has sccache; then
  cargo binstall --no-confirm --locked sccache \
    || cargo install --locked sccache \
    || true
fi
has sccache && export RUSTC_WRAPPER=sccache

log "Installing Cargo tools..."
cargo binstall --no-confirm --locked \
  cargo-edit \
  cargo-watch \
  cargo-nextest \
  cargo-expand \
  cargo-outdated \
  cargo-audit \
  bacon \
  mcfly \
  || true

# =============================================================================
# 3. PYTHON / UV
# =============================================================================
if ! has uv; then
  log "Installing uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi
export PATH="$HOME/.local/bin:$HOME/.local/share/uv/tools/bin:$PATH"

uv python install 3.12       || true
uv tool install ruff         || true
uv tool install basedpyright || true
uv tool install ipython      || true
uv tool install pre-commit   || true

# =============================================================================
# 4. NEOVIM (prebuilt tarball)
# =============================================================================
if ! has nvim; then
  log "Installing Neovim (${NVIM_ARCH})..."
  curl -fsSL -o /tmp/nvim.tar.gz \
    "https://github.com/neovim/neovim/releases/download/stable/nvim-linux-${NVIM_ARCH}.tar.gz"
  tar -xzf /tmp/nvim.tar.gz -C /tmp
  rm -rf "$HOME/.local/nvim"
  mv "/tmp/nvim-linux-${NVIM_ARCH}" "$HOME/.local/nvim"
  ln -sf "$HOME/.local/nvim/bin/nvim" "$USER_BIN/nvim"
  rm -f /tmp/nvim.tar.gz
fi

# =============================================================================
# 5. STARSHIP
# =============================================================================
if ! has starship; then
  log "Installing starship..."
  BIN_DIR="$USER_BIN" sh -c "$(curl -fsSL https://starship.rs/install.sh)" -- --yes
fi

# =============================================================================
# 6. YAZI
# =============================================================================
if ! has yazi || ! has ya; then
  log "Installing yazi (${YAZI_ARCH})..."
  _tmp="$(mktemp -d)"
  curl -fsSL -o "$_tmp/yazi.zip" \
    "https://github.com/sxyazi/yazi/releases/latest/download/yazi-${YAZI_ARCH}-unknown-linux-gnu.zip"
  unzip -q -o "$_tmp/yazi.zip" -d "$_tmp"
  find "$_tmp" -type f -name yazi -exec install -m 0755 {} "$USER_BIN/yazi" \;
  find "$_tmp" -type f -name ya   -exec install -m 0755 {} "$USER_BIN/ya"   \;
  rm -rf "$_tmp"
fi

# =============================================================================
# 7. LAZYGIT
# =============================================================================
if ! has lazygit; then
  log "Installing lazygit (${LAZYGIT_ARCH})..."
  _ver="$(curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest \
    | grep -Po '"tag_name": "v\K[^"]*')"
  curl -fsSL -o /tmp/lazygit.tar.gz \
    "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${_ver}_Linux_${LAZYGIT_ARCH}.tar.gz"
  tar -xzf /tmp/lazygit.tar.gz -C "$USER_BIN" lazygit
  rm -f /tmp/lazygit.tar.gz
fi

# =============================================================================
# 8. SHFMT (not in Ubuntu apt repos)
# =============================================================================
if ! has shfmt; then
  log "Installing shfmt..."
  _ver="$(curl -fsSL https://api.github.com/repos/mvdan/sh/releases/latest \
    | grep -Po '"tag_name": "v\K[^"]*')"
  curl -fsSL -o "$USER_BIN/shfmt" \
    "https://github.com/mvdan/sh/releases/latest/download/shfmt_v${_ver}_linux_${ARCH_ID}"
  chmod +x "$USER_BIN/shfmt"
fi

# =============================================================================
# 9. CHEZMOI + DOTFILES
# .chezmoiexternal.toml handles: oh-my-zsh, zsh plugins, spaceship, nvim-config
# No manual git clones needed — chezmoi manages all of it.
# =============================================================================
if ! has chezmoi; then
  log "Installing chezmoi..."
  sh -c "$(curl -fsLS get.chezmoi.io/lb)" -- -b "$USER_BIN"
fi

log "Applying dotfiles (Kelvinyu1117/dotfiles)..."
chezmoi init --apply --force https://github.com/Kelvinyu1117/dotfiles.git \
  || warn "chezmoi init --apply returned non-zero (check above)"

# =============================================================================
# 10. ZSH AS DEFAULT SHELL
# =============================================================================
ZSH_PATH="$(command -v zsh)"
grep -qxF "$ZSH_PATH" /etc/shells \
  || echo "$ZSH_PATH" | sudo tee -a /etc/shells >/dev/null

# chsh may be a no-op in OrbStack VMs — soft-fail
if has chsh; then
  chsh -s "$ZSH_PATH" "${USER:-$(whoami)}" \
    || warn "chsh failed — set shell via OrbStack settings or re-login"
fi

# Fallback for non-zsh login shells; guard against exec loop
if ! grep -q "exec zsh" "$HOME/.profile" 2>/dev/null; then
  printf '\n%s\n%s\n' \
    '# Switch to zsh for non-zsh login shells' \
    '[ -z "${ZSH_VERSION:-}" ] && command -v zsh >/dev/null && exec zsh -l' \
    >> "$HOME/.profile"
fi

# =============================================================================
# 11. LAZY.NVIM SYNC
# =============================================================================
if has nvim; then
  log "Syncing Lazy.nvim plugins (headless)..."
  nvim --headless "+Lazy! sync" +qa 2>/dev/null || true
fi

# =============================================================================
# VERSIONS SUMMARY
# =============================================================================
_v() { has "$1" && "$1" --version 2>&1 | head -1 || printf '(not found)'; }
echo
echo "════════════════════ versions ════════════════════"
printf "%-16s %s\n" "nvim:"        "$(_v nvim)"
printf "%-16s %s\n" "zsh:"         "$(_v zsh)"
printf "%-16s %s\n" "clang++:"     "$(has clang++ && clang++ --version | head -1 || printf '(not found)')"
printf "%-16s %s\n" "clangd:"      "$(_v clangd)"
printf "%-16s %s\n" "cmake:"       "$(_v cmake)"
printf "%-16s %s\n" "ninja:"       "$(_v ninja)"
printf "%-16s %s\n" "rustc:"       "$(_v rustc)"
printf "%-16s %s\n" "cargo:"       "$(_v cargo)"
printf "%-16s %s\n" "uv:"          "$(_v uv)"
printf "%-16s %s\n" "python3:"     "$(_v python3)"
printf "%-16s %s\n" "ruff:"        "$(_v ruff)"
printf "%-16s %s\n" "yazi:"        "$(_v yazi)"
printf "%-16s %s\n" "lazygit:"     "$(_v lazygit)"
printf "%-16s %s\n" "starship:"    "$(_v starship)"
printf "%-16s %s\n" "chezmoi:"     "$(_v chezmoi)"
printf "%-16s %s\n" "shfmt:"       "$(_v shfmt)"
echo "══════════════════════════════════════════════════"
log "Done. Open a new shell or run: exec zsh"
