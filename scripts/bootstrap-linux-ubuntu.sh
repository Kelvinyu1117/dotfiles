#!/usr/bin/env bash
set -Eeuo pipefail

USER_BIN="$HOME/.local/bin"
USER_LOCAL="$HOME/.local"
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

log() { echo "[info] $*"; }
warn() { echo "[warn] $*"; }
die() { echo "[error] $*" >&2; exit 1; }

mkdir -p "$USER_BIN" "$USER_LOCAL"
export PATH="$USER_BIN:$HOME/.cargo/bin:$PATH"

ARCH="$(uname -m)"
case "$ARCH" in
  x86_64|amd64)
    NVIM_ARCH="x86_64"
    LAZYGIT_ARCH="x86_64"
    YAZI_ARCH="x86_64"
    ;;
  aarch64|arm64)
    NVIM_ARCH="arm64"
    LAZYGIT_ARCH="arm64"
    YAZI_ARCH="aarch64"
    ;;
  *)
    die "unsupported arch: $ARCH"
    ;;
esac

PATH_LINE='export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.local/share/uv/tools:$PATH"'

# -------------------------
# Apt packages
# -------------------------
log "Installing Ubuntu packages..."

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

# -------------------------
# Rust
# -------------------------
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

# -------------------------
# Python / uv
# -------------------------
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

# -------------------------
# Neovim
# -------------------------
if ! command -v nvim >/dev/null; then
  log "Installing Neovim for ${ARCH}..."
  rm -rf "$HOME/.local/nvim" "$USER_BIN/nvim" /tmp/nvim.tar.gz /tmp/nvim-linux-*

  curl -fsSL -o /tmp/nvim.tar.gz \
    "https://github.com/neovim/neovim/releases/download/stable/nvim-linux-${NVIM_ARCH}.tar.gz"

  tar -xzf /tmp/nvim.tar.gz -C /tmp
  mv "/tmp/nvim-linux-${NVIM_ARCH}" "$HOME/.local/nvim"
  ln -sf "$HOME/.local/nvim/bin/nvim" "$USER_BIN/nvim"
fi

# -------------------------
# oh-my-zsh + plugins
# -------------------------
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  log "Installing oh-my-zsh..."
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

mkdir -p "$ZSH_CUSTOM/plugins" "$ZSH_CUSTOM/themes"

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
  log "Installing zsh-autosuggestions..."
  git clone --depth=1 \
    https://github.com/zsh-users/zsh-autosuggestions \
    "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
fi

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
  log "Installing zsh-syntax-highlighting..."
  git clone --depth=1 \
    https://github.com/zsh-users/zsh-syntax-highlighting.git \
    "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
fi

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-completions" ]; then
  log "Installing zsh-completions..."
  git clone --depth=1 \
    https://github.com/zsh-users/zsh-completions \
    "$ZSH_CUSTOM/plugins/zsh-completions"
fi

if [ ! -d "$ZSH_CUSTOM/themes/spaceship-prompt" ]; then
  log "Installing spaceship prompt..."
  git clone --depth=1 \
    https://github.com/spaceship-prompt/spaceship-prompt.git \
    "$ZSH_CUSTOM/themes/spaceship-prompt"
  ln -sf "$ZSH_CUSTOM/themes/spaceship-prompt/spaceship.zsh-theme" \
    "$ZSH_CUSTOM/themes/spaceship.zsh-theme"
fi

# -------------------------
# Starship also kept available
# -------------------------
if ! command -v starship >/dev/null; then
  log "Installing starship..."
  BIN_DIR="$USER_BIN" sh -c "$(curl -fsSL https://starship.rs/install.sh)" -- --yes
fi

# -------------------------
# Yazi
# -------------------------
if ! command -v yazi >/dev/null || ! command -v ya >/dev/null; then
  log "Installing yazi for ${ARCH}..."
  tmpdir="$(mktemp -d)"
  pushd "$tmpdir" >/dev/null

  curl -fsSLO \
    "https://github.com/sxyazi/yazi/releases/latest/download/yazi-${YAZI_ARCH}-unknown-linux-gnu.zip"

  unzip -o *.zip
  find . -type f -name yazi -exec install -m 0755 {} "$USER_BIN/yazi" \;
  find . -type f -name ya -exec install -m 0755 {} "$USER_BIN/ya" \;

  popd >/dev/null
  rm -rf "$tmpdir"
fi

# -------------------------
# lazygit
# -------------------------
if ! command -v lazygit >/dev/null; then
  log "Installing lazygit for ${ARCH}..."
  VERSION="$(curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest |
    grep -Po '"tag_name": "v\K[^"]*')"

  rm -f /tmp/lazygit.tar.gz "$USER_BIN/lazygit"

  curl -fsSL -o /tmp/lazygit.tar.gz \
    "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${VERSION}_Linux_${LAZYGIT_ARCH}.tar.gz"

  tar -xzf /tmp/lazygit.tar.gz -C "$USER_BIN" lazygit
fi

# -------------------------
# chezmoi
# -------------------------
if ! command -v chezmoi >/dev/null; then
  log "Installing chezmoi..."
  sh -c "$(curl -fsLS get.chezmoi.io/lb)" -- -b "$USER_BIN"
fi

# -------------------------
# zshrc fallback if chezmoi hasn't applied yet
# -------------------------
if [ ! -f "$HOME/.zshrc" ]; then
  cat > "$HOME/.zshrc" <<'EOF'
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="spaceship"

plugins=(
  git
  fzf
  zsh-autosuggestions
  zsh-syntax-highlighting
  zsh-completions
)

source "$ZSH/oh-my-zsh.sh"

export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.local/share/uv/tools:$PATH"

eval "$(mcfly init zsh)" 2>/dev/null || true

# If you prefer starship instead of spaceship, uncomment:
# ZSH_THEME=""
# eval "$(starship init zsh)"
EOF
fi

for f in "$HOME/.profile" "$HOME/.bashrc" "$HOME/.zprofile" "$HOME/.zshrc"; do
  [ -f "$f" ] || : > "$f"
  grep -qxF "$PATH_LINE" "$f" || echo "$PATH_LINE" >> "$f"
done

# -------------------------
# dotfiles
# -------------------------
if [ -d ./.git ] || [ -f ./dot_zshrc ] || [ -f ./home/.zshrc ]; then
  log "Applying chezmoi dotfiles from current directory..."
  chezmoi --source . apply -R --force -k || warn "chezmoi apply returned non-zero"
fi

# -------------------------
# Lazy.nvim sync
# -------------------------
if command -v nvim >/dev/null; then
  log "Syncing Lazy.nvim if configured..."
  nvim --headless "+Lazy! sync" +qa || true
fi

# -------------------------
# Zsh as default shell + history + mcfly
# -------------------------
log "Configuring zsh as default shell..."

ZSH_PATH="$(command -v zsh)"

# ensure zsh is in /etc/shells
if ! grep -qx "$ZSH_PATH" /etc/shells; then
  echo "$ZSH_PATH" | sudo tee -a /etc/shells >/dev/null
fi

# set default shell (non-fatal if it fails, e.g. container env)
if command -v chsh >/dev/null; then
  chsh -s "$ZSH_PATH" "$USER" || warn "chsh failed (likely container), will fallback to exec zsh"
fi

# ensure history file exists
touch "$HOME/.zsh_history"
chmod 600 "$HOME/.zsh_history"

# ensure zshrc exists
[ -f "$HOME/.zshrc" ] || touch "$HOME/.zshrc"

# inject history config (idempotent)
grep -q "HISTFILE=" "$HOME/.zshrc" || cat >> "$HOME/.zshrc" <<'EOF'

# history config
export HISTFILE=~/.zsh_history
export HISTSIZE=100000
export SAVEHIST=100000
setopt appendhistory
setopt sharehistory
setopt hist_ignore_all_dups
EOF

# inject mcfly init (idempotent)
if command -v mcfly >/dev/null; then
  grep -q "mcfly init zsh" "$HOME/.zshrc" || \
    echo 'eval "$(mcfly init zsh)"' >> "$HOME/.zshrc"
fi

# fallback: force zsh for SSH / non-login shells
if ! grep -q "exec zsh" "$HOME/.profile"; then
  echo 'exec zsh' >> "$HOME/.profile"
fi

hash -r || true

echo
echo "===== versions ====="
nvim --version | head -1 || true
zsh --version || true
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
yazi --version || true
ya --version || true
lazygit --version || true
starship --version || true
chezmoi --version || true
echo "===================="

log "Ubuntu dev VM bootstrap complete."
