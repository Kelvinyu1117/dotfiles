#!/usr/bin/env bash
# Set up (or update) a machine: packages -> config links -> oh-my-zsh -> git identity -> Neovim.
# Safe to re-run; running it again is how you update.
#
#   git clone https://github.com/Kelvinyu1117/dotfiles ~/dotfiles && ~/dotfiles/install.sh
#
# Flags:
#   --no-packages   skip Homebrew/apt installs (just links, shell plugins, Neovim)
#   --links-only    only (re)create the symlinks
#   --update        also `git pull` this repo, oh-my-zsh and the zsh plugins
set -Eeuo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES=1
LINKS_ONLY=0
UPDATE=0
for arg in "$@"; do
  case "$arg" in
  --no-packages) PACKAGES=0 ;;
  --links-only) LINKS_ONLY=1 ;;
  --update) UPDATE=1 ;;
  -h | --help)
    sed -n '2,11p' "$0"
    exit 0
    ;;
  *)
    echo "unknown option: $arg (see --help)" >&2
    exit 1
    ;;
  esac
done

log() { printf '\033[0;32m[info]\033[0m  %s\n' "$*"; }
warn() { printf '\033[0;33m[warn]\033[0m  %s\n' "$*"; }
has() { command -v "$1" >/dev/null 2>&1; }

# Ask a question even when stdin isn't a terminal (e.g. piped from curl). Empty when impossible.
ask() {
  local prompt="$1" answer=""
  if { : </dev/tty; } 2>/dev/null; then
    printf '%s' "$prompt" >/dev/tty
    IFS= read -r answer </dev/tty || true
  fi
  printf '%s' "$answer"
}

if [ "$UPDATE" -eq 1 ] && [ -d "$REPO/.git" ]; then
  log "Updating the dotfiles repo..."
  git -C "$REPO" pull --ff-only || warn "could not fast-forward $REPO (local changes?)"
fi

# 1. Packages -------------------------------------------------------------------
if [ "$LINKS_ONLY" -eq 0 ] && [ "$PACKAGES" -eq 1 ]; then
  case "$(uname -s)" in
  Darwin) bash "$REPO/scripts/packages-macos.sh" ;;
  Linux)
    if has apt-get; then
      bash "$REPO/scripts/packages-ubuntu.sh"
    else
      warn "no package script for this Linux distro; install the tools from the README by hand"
    fi
    ;;
  *) warn "unsupported OS $(uname -s); skipping packages" ;;
  esac
fi

# 2. Config symlinks ------------------------------------------------------------
log "Linking config files from $REPO/home into $HOME..."
sh "$REPO/scripts/link.sh"
[ "$LINKS_ONLY" -eq 1 ] && exit 0

# 3. oh-my-zsh + plugins, pinned -------------------------------------------------
ZSH_DIR="$HOME/.oh-my-zsh"
ZSH_CUSTOM_DIR="$ZSH_DIR/custom"

# clone_pinned <dir> <url> [tag]
clone_pinned() {
  local dir="$1" url="$2" tag="${3:-}"
  if [ -d "$dir/.git" ]; then
    if [ "$UPDATE" -eq 1 ] && [ -z "$tag" ]; then
      git -C "$dir" pull --ff-only --quiet || warn "could not update $dir"
    fi
    return
  fi
  if [ -e "$dir" ]; then
    # e.g. a plain copy left behind by the old chezmoi setup; keep it, it works.
    return
  fi
  log "Installing $(basename "$dir")${tag:+ $tag}..."
  if [ -n "$tag" ]; then
    git clone --quiet --depth 1 --branch "$tag" "$url" "$dir"
  else
    git clone --quiet --depth 1 "$url" "$dir"
  fi
}

if has git; then
  clone_pinned "$ZSH_DIR" https://github.com/ohmyzsh/ohmyzsh.git
  clone_pinned "$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions" \
    https://github.com/zsh-users/zsh-autosuggestions.git v0.7.1
  clone_pinned "$ZSH_CUSTOM_DIR/plugins/zsh-syntax-highlighting" \
    https://github.com/zsh-users/zsh-syntax-highlighting.git 0.8.0
  clone_pinned "$ZSH_CUSTOM_DIR/themes/spaceship-prompt" \
    https://github.com/spaceship-prompt/spaceship-prompt.git v4.19.0
  ln -sfn "$ZSH_CUSTOM_DIR/themes/spaceship-prompt/spaceship.zsh-theme" \
    "$ZSH_CUSTOM_DIR/themes/spaceship.zsh-theme"
else
  warn "git not found; skipping oh-my-zsh"
fi

# 4. Git identity (kept out of the repo, in ~/.gitconfig.local) ------------------
if [ ! -f "$HOME/.gitconfig.local" ]; then
  name="$(ask 'Git name (for commits): ')"
  email="$(ask 'Git email: ')"
  if [ -n "$name" ] && [ -n "$email" ]; then
    printf '[user]\n\tname = %s\n\temail = %s\n' "$name" "$email" >"$HOME/.gitconfig.local"
    log "Wrote ~/.gitconfig.local"
  else
    warn "no git identity set; create ~/.gitconfig.local (see README) before committing"
  fi
fi

# 5. Neovim config (separate repo, its own installer) ----------------------------
NVIM_CONFIG_DIR="${NVIM_CONFIG_DIR:-$HOME/nvim-config}"
if has nvim; then
  if [ ! -d "$NVIM_CONFIG_DIR/.git" ]; then
    log "Cloning nvim-config into $NVIM_CONFIG_DIR..."
    git clone --quiet https://github.com/Kelvinyu1117/nvim-config.git "$NVIM_CONFIG_DIR"
  fi
  NVIM_CONFIG_DIR="$NVIM_CONFIG_DIR" sh "$NVIM_CONFIG_DIR/install.sh" ||
    warn "nvim-config install.sh failed (see above)"
else
  warn "nvim not found; skipping the Neovim config"
fi

# 6. zsh as the login shell ------------------------------------------------------
if has zsh && [ "$(basename "${SHELL:-}")" != "zsh" ]; then
  ZSH_PATH="$(command -v zsh)"
  if ! grep -qxF "$ZSH_PATH" /etc/shells 2>/dev/null; then
    echo "$ZSH_PATH" | sudo tee -a /etc/shells >/dev/null || true
  fi
  chsh -s "$ZSH_PATH" || warn "chsh failed; set your login shell to $ZSH_PATH manually"
fi

cat <<EOF

Done. Next steps:
  - Open a new terminal (or run: exec zsh).
  - Ghostty: restart it to pick up ~/.config/ghostty/config.
  - First nvim start: let Mason finish installing (:Mason), then restart nvim once.
  - On a machine with an NVIDIA GPU: run :CudaClangdSetup in nvim once.
Update later with: $REPO/install.sh --update
EOF
