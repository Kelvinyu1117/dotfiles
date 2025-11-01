#!/bin/bash
set -e

linux_packages=(neovim git curl zsh)

echo "Updating apt and installing packages: ${linux_packages[*]}"
sudo apt-get update
sudo apt-get install -y "${linux_packages[@]}"

if ! command -v chezmoi &>/dev/null; then
  echo "chezmoi not found, installing..."
  sh -c "$(curl -fsLS get.chezmoi.io)"
fi

echo "Applying chezmoi dotfiles..."
chezmoi apply -R


if command -v nvim &>/dev/null; then
  echo "Syncing Neovim plugins with Lazy.nvim (if configured)..."
  nvim --headless "+Lazy! sync" +qa || echo "Lazy.nvim sync failed or is not configured"
fi

# Optional: Set zsh as default shell if not already
if [ "$SHELL" != "$(which zsh)" ]; then
  echo "Setting zsh as your default shell..."
  chsh -s "$(which zsh)"
fi

echo "Linux bootstrap complete!"

