#!/bin/bash
set -e

linux_packages=(git curl zsh unzip)

echo "Updating apt and installing packages: ${linux_packages[*]}"
sudo apt-get update
sudo apt-get install -y "${linux_packages[@]}"

# Install latest Neovim (AppImage)
echo "Installing latest Neovim as AppImage..."
mkdir -p "$HOME/.local/bin"
curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim.appimage
mv nvim.appimage "$HOME/.local/bin/nvim.appimage"

# Create symlink named 'nvim' pointing to 'nvim.appimage'
ln -sf "$HOME/.local/bin/nvim.appimage" "$HOME/.local/bin/nvim"
export PATH="$HOME/.local/bin:$PATH"

# Optionally, create global symlink for nvim (requires sudo)
if [ -f "$HOME/.local/bin/nvim.appimage" ]; then
  sudo ln -sf "$HOME/.local/bin/nvim.appimage" /usr/local/bin/nvim
  echo "Symlinked ~/.local/bin/nvim.appimage to /usr/local/bin/nvim"
fi

# Verify Neovim installation
if command -v nvim &>/dev/null; then
  echo "Neovim installed: $(nvim --version | head -1)"
else
  echo "Failed to install Neovim."
  exit 1
fi

# Install chezmoi if not found
if ! command -v chezmoi &>/dev/null; then
  echo "chezmoi not found, installing..."
  sh -c "$(curl -fsLS get.chezmoi.io)"
  sleep 2
fi

# Add chezmoi to PATH if necessary
if ! command -v chezmoi &>/dev/null; then
  export PATH="$HOME/.local/bin:$PATH"
fi

if ! command -v chezmoi &>/dev/null; then
  echo "Unable to find chezmoi after installation. Exiting."
  exit 1
fi

echo "Applying chezmoi dotfiles..."
chezmoi apply -R

# Install yazi binary if not present
if ! command -v yazi &>/dev/null; then
  echo "yazi not found, installing..."
  cd "$HOME/.local/bin"
  curl -LO https://github.com/sxyazi/yazi/releases/latest/download/yazi-x86_64-unknown-linux-gnu.zip
  unzip -o yazi-x86_64-unknown-linux-gnu.zip
  mv yazi-x86_64-unknown-linux-gnu/yazi .
  rm -r yazi-x86_64-unknown-linux-gnu yazi-x86_64-unknown-linux-gnu.zip
  chmod +x yazi
  export PATH="$HOME/.local/bin:$PATH"
  cd -
fi

if command -v yazi &>/dev/null; then
  echo "Yazi installed successfully: $(yazi --version 2>/dev/null)"
else
  echo "Failed to install yazi."
fi

# Install Starship prompt if not present
if ! command -v starship &>/dev/null; then
  echo "Starship prompt not found, installing..."
  sh -c "$(curl -fsSL https://starship.rs/install.sh)" -- --bin-dir "$HOME/.local/bin" --yes
  export PATH="$HOME/.local/bin:$PATH"
fi

if command -v starship &>/dev/null; then
  echo "Starship installed: $(starship --version)"
  echo 'To activate Starship prompt in zsh, add this to your ~/.zshrc:'
  echo
