#!/bin/bash
set -e

mac_packages=(neovim git chezmoi zsh yazi ripgrep)

if ! command -v brew &>/dev/null; then
  echo "Homebrew not found. Please install Homebrew: https://brew.sh/"
  exit 1
fi

echo "Installing packages with Homebrew: ${mac_packages[*]}"
brew install "${mac_packages[@]}"

echo "Applying chezmoi dotfiles..."
chezmoi apply -R

if command -v nvim &>/dev/null; then
  echo "Syncing Neovim plugins with Lazy.nvim (if configured)..."
  nvim --headless "+Lazy! sync" +qa || echo "Lazy.nvim sync failed or is not configured"
fi

echo "macOS bootstrap complete!"

