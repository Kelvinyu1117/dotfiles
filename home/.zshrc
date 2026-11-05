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

# No framework (oh-my-zsh etc.): every line below is plain zsh you can read and change.
# Plugins come from Homebrew/apt; the prompt is starship (~/.config/starship.toml).

# ── completion ────────────────────────────────────────────────────────────────
mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
autoload -Uz compinit && compinit -d "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"
zstyle ':completion:*' menu select                         # Tab cycles through a menu
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'  # case-insensitive
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# ── behaviour ─────────────────────────────────────────────────────────────────
setopt auto_cd              # type a directory name to cd into it
setopt interactive_comments # allow `# comments` on the command line
bindkey -e                  # emacs-style line editing (Ctrl-a/Ctrl-e/Ctrl-w, like bash)
bindkey '^[[1;5D' backward-word # Ctrl-←
bindkey '^[[1;5C' forward-word  # Ctrl-→
autoload -Uz edit-command-line && zle -N edit-command-line
bindkey '^x^e' edit-command-line # Ctrl-x Ctrl-e: edit the current command in nvim

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

# ── fzf: Ctrl-R history search, Ctrl-T insert a file path, Alt-C cd into a folder ─
if command -v fzf >/dev/null; then
  if fzf --zsh >/dev/null 2>&1; then # fzf 0.48+
    source <(fzf --zsh)
  else # older fzf from apt
    for f in /usr/share/doc/fzf/examples/key-bindings.zsh /usr/share/doc/fzf/examples/completion.zsh; do
      [[ -r "$f" ]] && source "$f"
    done
  fi
fi

# ── plugins (installed by Homebrew or apt) ────────────────────────────────────
# zsh-autosuggestions: grey suggestion from your history, → accepts it.
# zsh-syntax-highlighting: colors commands as you type (red = not found). Must be sourced last.
# ($HOMEBREW_PREFIX is set by `brew shellenv` above; empty on Linux.)
for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
  for dir in "${HOMEBREW_PREFIX:-/nonexistent}/share/$plugin" "/usr/share/$plugin"; do
    if [[ -r "$dir/$plugin.zsh" ]]; then
      source "$dir/$plugin.zsh"
      break
    fi
  done
done
unset plugin dir

# ── prompt ────────────────────────────────────────────────────────────────────
command -v starship >/dev/null && eval "$(starship init zsh)"

# ── per-machine overrides (not in git) ────────────────────────────────────────
[[ -r "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"

# ── Zellij on SSH ─────────────────────────────────────────────────────────────
# `ssh desktop` lands in the Zellij session "main" (created if missing). If the connection drops,
# everything keeps running; ssh in again to get it back. Leaving Zellij returns to this shell.
# Skipped for local terminals, scp/rsync (non-interactive), and terminals inside nvim/Zellij.
if [[ -o interactive && -n "$SSH_CONNECTION" && -z "$ZELLIJ" && -z "$NVIM" ]] && command -v zellij >/dev/null; then
  zellij attach --create main
fi
