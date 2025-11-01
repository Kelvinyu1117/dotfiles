#!/usr/bin/env bash
set -Eeuo pipefail

# ---------- Detect environment ----------
OS="$(uname -s)"
ARCH="$(uname -m)"                  # x86_64, aarch64
HAS_APT=$(command -v apt-get >/dev/null && echo 1 || echo 0)
HAS_APK=$(command -v apk >/dev/null && echo 1 || echo 0)
USER_BIN="$HOME/.local/bin"
USER_LOCAL="$HOME/.local"
PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'

# libc detection (glibc vs musl)
detect_libc() {
  if ldd --version 2>&1 | grep -qi musl; then
    echo "musl"
  elif command -v getconf >/dev/null && getconf GNU_LIBC_VERSION >/dev/null 2>&1; then
    echo "glibc"
  else
    # Fallback guess: if /lib64/ld-linux-x86-64.so.2 exists we assume glibc on amd64
    [ -e /lib64/ld-linux-x86-64.so.2 ] && echo "glibc" || echo "unknown"
  fi
}
LIBC="$(detect_libc)"

# ---------- Utilities ----------
ensure_path_persist() {
  mkdir -p "$USER_BIN" "$USER_LOCAL"
  export PATH="$USER_BIN:$PATH"
  for f in "$HOME/.profile" "$HOME/.zprofile" "$HOME/.zshrc"; do
    [ -f "$f" ] || : > "$f"
    grep -qxF "$PATH_LINE" "$f" || echo "$PATH_LINE" >> "$f"
  done
}

install_common_tools_apt() {
  sudo apt-get update -y
  sudo apt-get install -y git curl zsh unzip ripgrep ca-certificates
}

install_common_tools_apk() {
  sudo apk update
  sudo apk add --no-cache git curl zsh unzip ripgrep ca-certificates
}

# ---------- Neovim installers ----------
install_nvim_alpine() {
  # Native musl packages avoid loader issues
  echo "[info] Installing Neovim via apk (Alpine/musl)…"
  sudo apk add --no-cache neovim || return 1
  command -v nvim >/dev/null || ln -sf /usr/bin/nvim "$USER_BIN/nvim"
  nvim --version | head -1
}

install_nvim_tarball_glibc() {
  # Choose correct asset by ARCH
  local arch_tar=""
  case "$ARCH" in
    x86_64|amd64) arch_tar="nvim-linux-x86_64.tar.gz" ;;
    aarch64|arm64) arch_tar="nvim-linux-arm64.tar.gz" ;;
    *) echo "[warn] Unknown arch '$ARCH'; trying x86_64 asset"; arch_tar="nvim-linux-x86_64.tar.gz" ;;
  esac

  # Prefer official release tarballs
  local urls=(
    "https://github.com/neovim/neovim/releases/download/stable/${arch_tar}"
    "https://github.com/neovim/neovim/releases/latest/download/${arch_tar}"
  )

  echo "[info] Installing Neovim (glibc tarball)…"
  rm -rf "$HOME/.local/nvim"
  for u in "${urls[@]}"; do
    if curl -fsSL -o /tmp/nvim.tar.gz "$u"; then
      tar -xzf /tmp/nvim.tar.gz -C /tmp
      mv /tmp/nvim-* "$HOME/.local/nvim"
      ln -sf "$HOME/.local/nvim/bin/nvim" "$USER_BIN/nvim"
      hash -r || true
      nvim --version | head -1 && return 0
    fi
  done
  return 1
}

install_nvim_deb_glibc() {
  # Fallback .deb (only for x86_64 as provided in neovim-releases)
  if [ "${ARCH}" != "x86_64" ] && [ "${ARCH}" != "amd64" ]; then
    return 1
  fi
  echo "[info] Installing Neovim via .deb…"
  curl -fsSL -o /tmp/nvim.deb \
    "https://github.com/neovim/neovim-releases/releases/latest/download/nvim-linux-x86_64.deb" || return 1
  sudo apt-get install -y /tmp/nvim.deb
  nvim --version | head -1
}

install_nvim_appimage_last_resort() {
  # AppImage needs libfuse2 or extraction
  echo "[info] Trying AppImage as last resort…"
  # Install FUSE runtime on Ubuntu/Debian
  if [ "$HAS_APT" -eq 1 ]; then
    sudo apt-get update -y
    sudo apt-get install -y libfuse2 || true
  fi
  local ai="nvim-linux-$( [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ] && echo arm64 || echo x86_64 ).appimage"
  local url="https://github.com/neovim/neovim/releases/download/stable/${ai}"
  curl -fsSL -o /tmp/nvim.appimage "$url" || return 1
  chmod +x /tmp/nvim.appimage

  # Try extract to avoid FUSE requirement
  if /tmp/nvim.appimage --appimage-extract >/dev/null 2>&1; then
    mv squashfs-root/usr/bin/nvim "$USER_BIN/nvim"
    rm -rf squashfs-root
  else
    mv /tmp/nvim.appimage "$USER_BIN/nvim"
  fi
  nvim --version | head -1
}

install_neovim() {
  case "$LIBC" in
    musl)
      # Alpine or musl-based: use apk package
      install_nvim_alpine && return 0
      ;;
    glibc|unknown)
      # Debian/Ubuntu (glibc) — tarball first, then .deb, then AppImage
      install_nvim_tarball_glibc && return 0
      [ "$HAS_APT" -eq 1 ] && install_nvim_deb_glibc && return 0
      install_nvim_appimage_last_resort && return 0
      ;;
  esac
  return 1
}

# ---------- Chezmoi / Yazi / Starship ----------
install_chezmoi() {
  if ! command -v chezmoi >/dev/null; then
    echo "[info] Installing chezmoi…"
    if [ "$HAS_APK" -eq 1 ]; then
      sudo apk add --no-cache chezmoi || true
    fi
    if ! command -v chezmoi >/dev/null; then
      sh -c "$(curl -fsLS get.chezmoi.io/lb)" -- -b "$USER_BIN"
    fi
  fi
  command -v chezmoi >/dev/null || { echo "[error] chezmoi not found after install"; return 1; }
}

install_yazi() {
  if command -v yazi >/dev/null; then return 0; fi
  echo "[info] Installing yazi…"
  if [ "$HAS_APK" -eq 1 ]; then
    # Prefer native package on Alpine
    sudo apk add --no-cache yazi || true
  fi
  if ! command -v yazi >/dev/null; then
    # Fallback to upstream static build zip
    tmpdir="$(mktemp -d)"
    pushd "$tmpdir" >/dev/null
    curl -fsSLO "https://github.com/sxyazi/yazi/releases/latest/download/yazi-$( [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ] && echo aarch64 || echo x86_64 )-unknown-linux-gnu.zip"
    unzip -o *.zip
    # Find the yazi binary path and install
    find . -type f -name yazi -exec install -m 0755 {} "$USER_BIN/yazi" \;
    popd >/dev/null
    rm -rf "$tmpdir"
  fi
  command -v yazi >/dev/null || echo "[warn] yazi not found after install (check release assets for your arch)"
}

install_starship() {
  if command -v starship >/dev/null; then return 0; fi
  echo "[info] Installing Starship prompt…"
  if [ "$HAS_APK" -eq 1 ]; then
    sudo apk add --no-cache starship || true
  fi
  if ! command -v starship >/dev/null; then
    BIN_DIR="$USER_BIN" sh -c "$(curl -fsSL https://starship.rs/install.sh)" -- --yes
  fi
}

# ---------- Default shell ----------
set_default_shell_zsh() {
  if command -v zsh >/dev/null; then
    if [ "${SHELL:-}" != "$(command -v zsh)" ]; then
      chsh -s "$(command -v zsh)" || echo "[warn] chsh failed (likely container) — skipping"
    fi
    # Only exec zsh for interactive bash shells
    if ! grep -q "exec zsh" "$HOME/.bashrc" 2>/dev/null; then
      {
        echo ''
        echo '# Auto-start zsh from interactive Bash'
        echo 'if [[ $- == *i* ]]; then exec zsh; fi'
      } >> "$HOME/.bashrc"
    fi
  fi
}

# ================== MAIN ==================
ensure_path_persist

# Base tooling
if [ "$HAS_APK" -eq 1 ]; then install_common_tools_apk; fi
if [ "$HAS_APT" -eq 1 ]; then install_common_tools_apt; fi

# Neovim (handles musl vs glibc & arch)
install_neovim || { echo "[error] Neovim installation failed."; exit 1; }

# Sync Lazy (no-op if not configured)
if command -v nvim >/dev/null; then
  echo "[info] Syncing Lazy.nvim (if configured)…"
  nvim --headless "+Lazy! sync" +qa || true
fi


# Yazi / Starship / Chezmoi
install_yazi
install_starship
install_chezmoi
echo "[info] Applying chezmoi dotfiles (current dir as source)…"
chezmoi --source . apply -R --force -k || echo "[warn] chezmoi apply returned non-zero"



# Default shell
set_default_shell_zsh

echo "[success] Linux bootstrap complete!"
