#!/usr/bin/env bash
set -Eeuo pipefail

USER_BIN="$HOME/.local/bin"
PATH_LINE='export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"'

log() { echo "[info] $*"; }
warn() { echo "[warn] $*"; }
die() { echo "[error] $*" >&2; exit 1; }

mkdir -p "$USER_BIN"
export PATH="$USER_BIN:$HOME/.cargo/bin:$PATH"

ARCH="$(uname -m)"
case "$ARCH" in
  x86_64|amd64)
    NVIM_ARCH="x86_64"
    LAZYGIT_ARCH="x86_64"
    ;;
  aarch64|arm64)
    NVIM_ARCH="arm64"
    LAZYGIT_ARCH="arm64"
    ;;
  *)
    die "unsupported arch: $ARCH"
    ;;
esac

sudo apt-get update -y
sudo apt-get install -y --no-install-recommends \
  build-essential \
  pkg-config \
  autoconf \
  automake \
  libtool \
  git \
  curl \
  wget \
  ca-certificates \
  gnupg \
  lsb-release \
  software-properties-common \
  zsh \
  tmux \
  unzip \
  zip \
  tar \
  xz-utils \
  file \
  tree \
  jq \
  htop \
  openssh-client \
  rsync \
  ripgrep \
  bat \
  fzf \
  eza \
  fd-find \
  shellcheck \
  shfmt \
  python3 \
  python3-dev \
  python3-venv \
  python3-pip \
  pipx \
  cmake \
  ninja-build \
  ccache \
  gdb \
  valgrind \
  clang \
  clangd \
  clang-format \
  clang-tidy \
  lldb \
  llvm \
  lld \
  libc++-dev \
  libc++abi-dev \
  libssl-dev \
  zlib1g-dev \
  libbz2-dev \
  libreadline-dev \
  libsqlite3-dev \
  libffi-dev \
  liblzma-dev \
  libncursesw5-dev \
  uuid-dev

ln -sf "$(command -v fdfind)" "$USER_BIN/fd" || true
ln -sf "$(command -v batcat)" "$USER_BIN/bat" || true

if ! command -v rustup >/dev/null; then
  log "Installing Rust..."
  curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs | \
    sh -s -- -y --profile default --default-toolchain stable
fi

export PATH="$HOME/.cargo/bin:$PATH"

rustup update stable || true
rustup component add rustfmt clippy rust-src rust-analyzer || true

cargo install --locked \
  cargo-edit \
  cargo-watch \
  cargo-nextest \
  cargo-expand \
  cargo-outdated \
  cargo-audit \
  bacon \
  sccache \
  mcfly || true

if ! command -v uv >/dev/null; then
  log "Installing uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi

export PATH="$HOME/.local/bin:$PATH"

uv python install 3.12 || true
uv tool install ruff || true
uv tool install basedpyright || true
uv tool install ipython || true
uv tool install pre-commit || true

if ! command -v nvim >/dev/null; then
  log "Installing Neovim for ${ARCH}..."
  rm -rf "$HOME/.local/nvim" "$USER_BIN/nvim" /tmp/nvim.tar.gz /tmp/nvim-linux-*

  curl -fsSL -o /tmp/nvim.tar.gz \
    "https://github.com/neovim/neovim/releases/download/stable/nvim-linux-${NVIM_ARCH}.tar.gz"

  tar -xzf /tmp/nvim.tar.gz -C /tmp
  mv "/tmp/nvim-linux-${NVIM_ARCH}" "$HOME/.local/nvim"
  ln -sf "$HOME/.local/nvim/bin/nvim" "$USER_BIN/nvim"
fi

if ! command -v starship >/dev/null; then
  log "Installing starship..."
  BIN_DIR="$USER_BIN" sh -c "$(curl -fsSL https://starship.rs/install.sh)" -- --yes
fi

if ! command -v lazygit >/dev/null; then
  log "Installing lazygit for ${ARCH}..."
  VERSION="$(curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest |
    grep -Po '"tag_name": "v\K[^"]*')"

  rm -f /tmp/lazygit.tar.gz "$USER_BIN/lazygit"

  curl -fsSL -o /tmp/lazygit.tar.gz \
    "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${VERSION}_Linux_${LAZYGIT_ARCH}.tar.gz"

  tar -xzf /tmp/lazygit.tar.gz -C "$USER_BIN" lazygit
fi

if ! command -v chezmoi >/dev/null; then
  log "Installing chezmoi..."
  sh -c "$(curl -fsLS get.chezmoi.io/lb)" -- -b "$USER_BIN"
fi

for f in "$HOME/.profile" "$HOME/.bashrc" "$HOME/.zprofile" "$HOME/.zshrc"; do
  [ -f "$f" ] || : > "$f"
  grep -qxF "$PATH_LINE" "$f" || echo "$PATH_LINE" >> "$f"
done

hash -r || true

log "Syncing Lazy.nvim if configured..."
nvim --headless "+Lazy! sync" +qa || true

echo
echo "===== versions ====="
nvim --version | head -1 || true
clang++ --version | head -1 || true
clangd --version | head -1 || true
clang-format --version || true
clang-tidy --version | head -1 || true
lldb --version | head -1 || true
gdb --version | head -1 || true
cmake --version | head -1 || true
ninja --version || true
ccache --version | head -1 || true
rustc --version || true
cargo --version || true
rust-analyzer --version || true
uv --version || true
python3 --version || true
ruff --version || true
basedpyright --version || true
lazygit --version || true
starship --version || true
echo "===================="

log "Ubuntu headless dev VM bootstrap complete."
