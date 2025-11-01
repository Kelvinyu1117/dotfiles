#!/usr/bin/env bash
set -Eeuo pipefail

# ---------- Config ----------
USER_BIN="$HOME/.local/bin"
USER_LOCAL="$HOME/.local"
PATH_UPDATE_LINE='export PATH="$HOME/.local/bin:$PATH"'
# ----------------------------

linux_packages=(git curl zsh unzip ripgrep libfuse2)

echo "Updating apt and installing packages: ${linux_packages[*]}"
sudo apt-get update -y
sudo apt-get install -y "${linux_packages[@]}"

# Ensure ~/.local/bin exists and is on PATH for this run
mkdir -p "$USER_BIN" "$USER_LOCAL"
export PATH="$USER_BIN:$PATH"

# Persist PATH for future shells (zsh login + interactive, and bash via .profile)
touch "$HOME/.profile" "$HOME/.zprofile" "$HOME/.zshrc"
for f in "$HOME/.profile" "$HOME/.zprofile" "$HOME/.zshrc"; do
  if ! grep -qxF "$PATH_UPDATE_LINE" "$f"; then
    echo "$PATH_UPDATE_LINE" >> "$f"
  fi
done

# ---------- Neovim: install latest (robust tarball path; no FUSE required) ----------
install_nvim() {
  local url1="https://github.com/neovim/neovim/releases/download/stable/nvim-linux-x86_64.tar.gz"
  local url2="https://github.com/neovim/neovim-releases/releases/latest/download/nvim-linux-x86_64.tar.gz"

  echo "Installing latest Neovim (tarball)…"
  rm -rf "$HOME/.local/nvim"
  if curl -fsSL -o /tmp/nvim.tar.gz "$url1" || curl -fsSL -o /tmp/nvim.tar.gz "$url2"; then
    tar -xzf /tmp/nvim.tar.gz -C /tmp
    # The extracted dir is nvim-linux-x86_64
    mv /tmp/nvim-linux-x86_64 "$HOME/.local/nvim"
    ln -sf "$HOME/.local/nvim/bin/nvim" "$USER_BIN/nvim"
  else
    echo "Failed to download Neovim tarball."
    return 1
  fi
  hash -r || true
  nvim --version | head -1
}
install_nvim || { echo "Neovim install failed"; exit 1; }

# ---------- chezmoi ----------
if ! command -v chezmoi &>/dev/null; then
  echo "chezmoi not found, installing to $USER_BIN…"
  # Install binary into ~/.local/bin
  sh -c "$(curl -fsLS get.chezmoi.io/lb)" -- -b "$USER_BIN"
  hash -r || true
fi

if ! command -v chezmoi &>/dev/null; then
  echo "Unable to find chezmoi after installation. Exiting."
  exit 1
fi

echo "Applying chezmoi dotfiles from current directory…"
chezmoi --source . apply -R || echo "chezmoi apply returned non-zero (check your source)."

# ---------- yazi ----------
if ! command -v yazi &>/dev/null; then
  echo "yazi not found, installing…"
  tmpdir="$(mktemp -d)"
  pushd "$tmpdir" >/dev/null
  curl -fsSLO https://github.com/sxyazi/yazi/releases/latest/download/yazi-x86_64-unknown-linux-gnu.zip
  unzip -o yazi-x86_64-unknown-linux-gnu.zip
  mv yazi-x86_64-unknown-linux-gnu/yazi "$USER_BIN/"
  chmod +x "$USER_BIN/yazi"
  popd >/dev/null
  rm -rf "$tmpdir"
  hash -r || true
fi
command -v yazi >/dev/null && yazi --version 2>/dev/null || echo "yazi install failed"

# ---------- Starship ----------
if ! command -v starship &>/dev/null; then
  echo "Starship prompt not found, installing…"
  sh -c "$(curl -fsSL https://starship.rs/install.sh)" -- --bin-dir "$USER_BIN" --yes
  hash -r || true
fi
if command -v starship &>/dev/null; then
  echo "Starship installed: $(starship --version)"
  if ! grep -q 'eval "$(starship init zsh)"' "$HOME/.zshrc"; then
    echo 'eval "$(starship init zsh)"' >> "$HOME/.zshrc"
  fi
else
  echo "Failed to install Starship."
fi

# ---------- Lazy.nvim sync (safe no-op if not configured) ----------
if command -v nvim &>/dev/null; then
  echo "Syncing Neovim plugins with Lazy.nvim (if configured)…"
  nvim --headless "+Lazy! sync" +qa || echo "Lazy.nvim sync failed or is not configured"
fi

# ---------- Default shell: zsh ----------
if [ "${SHELL:-}" != "$(command -v zsh)" ]; then
  echo "Setting zsh as your default shell…"
  if ! chsh -s "$(command -v zsh)"; then
    echo "Warning: Failed to change shell with chsh. You may need to set your shell manually (common in containers)."
  fi
fi

# Start zsh for interactive Bash shells (avoid breaking non-interactive scripts)
if ! grep -q "exec zsh" "$HOME/.bashrc"; then
  {
    echo ''
    echo '# Start zsh automatically when opening an interactive Bash shell'
    echo 'if [[ $- == *i* ]]; then exec zsh; fi'
  } >> "$HOME/.bashrc"
fi

echo "Linux bootstrap complete!"
