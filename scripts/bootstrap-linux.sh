#!/usr/bin/env bash
set -Eeuo pipefail

# ---------- Config ----------
USER_BIN="$HOME/.local/bin"
PATH_UPDATE_LINE='export PATH="$HOME/.local/bin:$PATH"'
# ----------------------------

linux_packages=(git curl zsh unzip ripgrep libfuse2)

echo "Updating apt and installing packages: ${linux_packages[*]}"
sudo apt-get update
sudo apt-get install -y "${linux_packages[@]}"

# Ensure ~/.local/bin exists and is on PATH for this run
mkdir -p "$USER_BIN"
export PATH="$USER_BIN:$PATH"

# Persist PATH for future shells (zsh + bash)
touch "$HOME/.profile" "$HOME/.zprofile" "$HOME/.zshrc"
for f in "$HOME/.profile" "$HOME/.zprofile" "$HOME/.zshrc"; do
  if ! grep -qxF "$PATH_UPDATE_LINE" "$f"; then
    echo "$PATH_UPDATE_LINE" >> "$f"
  fi
done

# Install latest Neovim (AppImage)
echo "Installing latest Neovim as AppImage..."
curl -fsSL -o /tmp/nvim.appimage https://github.com/neovim/neovim/releases/latest/download/nvim.appimage
chmod +x /tmp/nvim.appimage
mv /tmp/nvim.appimage "$USER_BIN/nvim"

# Refresh command hash table in case shell caches paths
hash -r || true

# Verify Neovim installation
if command -v nvim &>/dev/null; then
  echo "Neovim installed: $(nvim --version | head -1)"
else
  echo "Failed to install Neovim."
  exit 1
fi

# Install chezmoi if not found
if ! command -v chezmoi &>/dev/null; then
  echo "chezmoi not found, installing to $USER_BIN..."
  # Use the installer that targets ~/.local/bin by default
  sh -c "$(curl -fsLS get.chezmoi.io/lb)" -- -b "$USER_BIN"
  hash -r || true
fi

# Final check for chezmoi; fix PATH bug from previous script (had ".local/bin" without $HOME)
if ! command -v chezmoi &>/dev/null; then
  export PATH="$USER_BIN:$PATH"
  echo "Exported PATH for current shell: $PATH"
fi

if ! command -v chezmoi &>/dev/null; then
  echo "Unable to find chezmoi after installation. Exiting."
  exit 1
fi

echo "Applying chezmoi dotfiles (from current directory)..."
chezmoi --source . apply -R || echo "chezmoi apply returned non-zero (check your source)."

# Install yazi if not present
if ! command -v yazi &>/dev/null; then
  echo "yazi not found, installing..."
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

if command -v yazi &>/dev/null; then
  echo "Yazi installed successfully: $(yazi --version 2>/dev/null || true)"
else
  echo "Failed to install yazi."
fi

# Install Starship prompt if not present
if ! command -v starship &>/dev/null; then
  echo "Starship prompt not found, installing..."
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

# Sync Neovim plugins with Lazy.nvim (if configured)
# Uses the documented Lazy user events; safe to no-op if Lazy isn't configured.
# Ref: https://lazy.folke.io/usage
if command -v nvim &>/dev/null; then
  echo "Syncing Neovim plugins with Lazy.nvim (if configured)..."
  nvim --headless "+lua vim.api.nvim_create_autocmd('User',{pattern='LazySync',once=true,callback=function() vim.cmd('qa') end})" "+Lazy! sync" || \
  nvim --headless "+Lazy! sync" +qa || echo "Lazy.nvim sync failed or not configured"
fi

# Safe attempt to set zsh as default shell
if [ "${SHELL:-}" != "$(command -v zsh)" ]; then
  echo "Setting zsh as your default shell..."
  if ! chsh -s "$(command -v zsh)"; then
    echo "Warning: Failed to change shell with chsh. You may need to set your shell manually (common in containers)."
  fi
fi

# Start zsh only for interactive Bash shells (avoid breaking non-interactive scripts)
if ! grep -q "exec zsh" "$HOME/.bashrc"; then
  {
    echo ''
    echo '# Start zsh automatically when opening an interactive Bash shell'
    echo 'if [[ $- == *i* ]]; then exec zsh; fi'
  } >> "$HOME/.bashrc"
fi

echo "Linux bootstrap complete!"
