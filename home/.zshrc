# ~/.zshrc: a symlink into ~/dotfiles/home/.zshrc. Edit it here, commit, push; other machines
# get it with `git pull`. Machine-specific bits go in ~/.zshrc.local (not in git).

# ── environment ───────────────────────────────────────────────────────────────
# Use ~/.config on macOS too (lazygit, ghostty, zellij, ... read their config from there).
export XDG_CONFIG_HOME="$HOME/.config"
export LANG=en_US.UTF-8
# Don't set TERM here: the terminal (Ghostty), Zellij and tmux set the right value themselves.
# Forcing xterm-256color breaks true color, italics and undercurl in Neovim.

# Homebrew (macOS): puts brew's bin dirs on PATH
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.local/share/uv/tools/bin:$PATH"

export EDITOR=nvim
export VISUAL=nvim

# ── oh-my-zsh ─────────────────────────────────────────────────────────────────
# Installed and pinned by ~/dotfiles/install.sh; `install.sh --update` updates it.
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="spaceship"
DISABLE_AUTO_UPDATE="true"
plugins=(
  fzf                     # Ctrl-R history search, Ctrl-T file search, Alt-C cd
  zsh-autosuggestions     # grey suggestion from history; → accepts it
  zsh-syntax-highlighting # must be last
)
[[ -r "$ZSH/oh-my-zsh.sh" ]] && source "$ZSH/oh-my-zsh.sh"

# ── history ───────────────────────────────────────────────────────────────────
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt share_history        # all open shells share one history
setopt hist_ignore_all_dups # no duplicates
setopt hist_reduce_blanks
setopt hist_ignore_space    # commands starting with a space aren't saved (handy for secrets)

# ── tools ─────────────────────────────────────────────────────────────────────
# zoxide: `z proj` jumps to the most used directory matching "proj"; `zi` picks interactively
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"

# ── aliases ───────────────────────────────────────────────────────────────────
alias vim="nvim"
alias vi="nvim"
alias vimdiff="nvim -d"

# git: a few short ones; use lazygit (`lg`, or <Space>gg in nvim) for anything bigger
alias g="git"
alias gs="git status -sb"
alias gd="git diff"
alias gl="git log --oneline --graph --decorate -20"
alias lg="lazygit"

if command -v eza >/dev/null; then
  alias ls="eza --group-directories-first"
  alias ll="eza -la --git --group-directories-first"
else
  alias ll="ls -la"
fi

# ── per-machine overrides (not in git) ────────────────────────────────────────
[[ -r "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"

# ── Zellij on SSH ─────────────────────────────────────────────────────────────
# `ssh desktop` lands in the Zellij session "main" (created if missing). If the connection drops,
# everything keeps running; ssh in again to get it back. Leaving Zellij returns to this shell.
# Skipped for local terminals, scp/rsync (non-interactive), and terminals inside nvim/Zellij.
if [[ -o interactive && -n "$SSH_CONNECTION" && -z "$ZELLIJ" && -z "$NVIM" ]] && command -v zellij >/dev/null; then
  zellij attach --create main
fi
