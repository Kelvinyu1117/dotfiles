#!/bin/bash
set -e

linux_packages=(neovim git curl zsh)

echo "Updating apt and installing packages: ${linux_packages[*]}"
sudo apt-get update
sudo apt-get install -y "${linux_packages[@]}"

# Install chezmoi if not found
if ! command -v chezmoi &>/dev/null; then
  echo "chezmoi not found, installing..."
  sh -c "$(curl -fsLS get.chezmoi.io/lb)"
  sleep 2
fi

# Add default install path to PATH if chezmoi still not found
if ! command -v chezmoi &>/dev/null; then
    export PATH=".local/bin:$PATH"
    echo "Exporting PATH=$PATH"
fi

# Final check for chezmoi
if ! command -v chezmoi &>/dev/null; then
  echo "Unable to find chezmoi after installation. Exiting."
  exit 1
fi

echo "Applying chezmoi dotfiles..."
chezmoi --source . apply -R

# Install yazi binary if not present
if ! command -v yazi &>/dev/null; then
  echo "yazi not found, installing..."
  mkdir -p "$HOME/.local/bin"
  cd "$HOME/.local/bin"
  curl -LO https://github.com/sxyazi/yazi/releases/latest/download/yazi-x86_64-unknown-linux-gnu.zip
  unzip -o yazi-x86_64-unknown-linux-gnu.zip
  mv yazi-x86_64-unknown-linux-gnu/yazi .
  rm -r yazi-x86_64-unknown-linux-gnu
  chmod +x yazi
  export PATH="$HOME/.local/bin:$PATH"
fi

if command -v yazi &>/dev/null; then
  echo "Yazi installed successfully."
else
  echo "Failed to install yazi."
fi

if command -v nvim &>/dev/null; then
  echo "Syncing Neovim plugins with Lazy.nvim (if configured)..."
  nvim --headless "+Lazy! sync" +qa || echo "Lazy.nvim sync failed or is not configured"
fi

# Optional: Set zsh as default shell if not already
if [ "$SHELL" != "$(which zsh)" ]; then
  echo "Setting zsh as your default shell..."
  # Run chsh but do not fail on error
  if ! chsh -s "$(which zsh)"; then
    echo "Warning: Failed to change shell with chsh. You may need to set your shell manually."
  fi
fi


echo "Linux bootstrap complete!"

