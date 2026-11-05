# dotfiles

Shell, terminal, git and multiplexer config for my Mac and Linux machines, plus one installer that
also sets up my [Neovim config](https://github.com/Kelvinyu1117/nvim-config).

## Setup

```bash
git clone https://github.com/Kelvinyu1117/dotfiles.git ~/dotfiles
```

```bash
~/dotfiles/install.sh
```

The installer is safe to run again and again. It does five things:
1. **Packages**: Homebrew + [`Brewfile`](Brewfile) on macOS, or
   [`scripts/packages-ubuntu.sh`](scripts/packages-ubuntu.sh) on Ubuntu/Debian.
2. **Links**: every file under [`home/`](home) gets symlinked to the same path in `$HOME`. Anything
   already there is moved to `~/.dotfiles-backup/<time>/` first.
   This includes the shell pieces: the starship prompt, zsh-autosuggestions and zsh-syntax-highlighting.
3. **Git identity**: asks for your name and email once, and stores them in `~/.gitconfig.local`.
4. **Neovim**: clones [nvim-config](https://github.com/Kelvinyu1117/nvim-config) to `~/nvim-config` and runs its installer.
5. **Login shell**: makes zsh your login shell.

Flags:
- `--no-packages`: skip Homebrew/apt
- `--links-only`: only redo the symlinks
- `--update`: also pull this repo first (packages update with `brew upgrade` / `apt upgrade`)

## How syncing works

The files in `$HOME` are **symlinks into this repo**. So `~/.zshrc` *is* `~/dotfiles/home/.zshrc`, and
changing a setting means editing the repo directly. There's no copy step and no template engine.

On one machine:

```bash
cd ~/dotfiles && git add -A && git commit -m "zsh: add alias" && git push
```

On the other:

```bash
cd ~/dotfiles && git pull
```

**To add a new config file**, move it into `home/` at the same path, then redo the links:

```bash
mv ~/.config/foo/config.toml ~/dotfiles/home/.config/foo/config.toml && ~/dotfiles/install.sh --links-only
```

**Per-machine settings** live in files that are deliberately *not* in git:
- `~/.zshrc.local`: sourced at the end of `.zshrc`
- `~/.gitconfig.local`: your git name and email, plus anything else machine-specific

## What's inside

```
install.sh                    the installer (bootstrap.sh still works and calls it)
Brewfile                      macOS packages
scripts/packages-macos.sh     Homebrew, Brewfile, Rust toolchain, uv tools
scripts/packages-ubuntu.sh    apt, Rust + cargo tools, uv, Neovim 0.12+, lazygit, zellij, delta, yazi
scripts/link.sh               the symlinker (--dry-run shows what it would do)
home/
├── .zshrc                    plain zsh: completion, history, fzf, plugins, zoxide, aliases, Zellij-on-SSH
├── .gitconfig                delta diffs, rebase on pull, zdiff3 conflicts, sane defaults
└── .config/
    ├── starship.toml         the prompt: dir, git, language versions, command time; user@host over SSH
    ├── git/ignore            global ignores (.DS_Store, clangd cache, ...)
    ├── ghostty/config        font, tokyonight colors, transparency, Option-as-Alt, OSC 52, SSH terminfo
    ├── zellij/config.kdl     locked mode by default, Ctrl/Alt+h/j/k/l shared with Neovim
    ├── lazygit/config.yml    delta as the diff pager
    └── yazi/                 yazi theme and flavors
```

## The workflow

```
Mac: Ghostty ──ssh──▶ Linux desktop: Zellij session "main" ──▶ nvim, builds, shells
```

- **`ssh desktop` drops you straight into Zellij.** `.zshrc` attaches to the session `main`, creating it
  the first time.
  - If Wi-Fi drops or the laptop sleeps, everything keeps running on the desktop. ssh in again to pick
    up where you left off.
  - Leaving Zellij returns you to a normal shell.
  - Local terminals and `scp`/`rsync` are not affected.
- **Zellij starts locked**, so every key goes to Neovim. Press `Ctrl g` to use Zellij's own keys (new
  pane, tab, floating pane, detach); the bottom bar lists them.
- **`Ctrl h/j/k/l`** moves between Neovim splits and Zellij panes alike, and **`Alt h/j/k/l`** resizes.
  The first time, Zellij asks you to allow the navigator plugin: press `y`.
- **Copying is seamless.** Yanking in Neovim, or selecting text in Zellij, lands in your Mac's clipboard,
  even over SSH. Ghostty allows this via OSC 52.
- **Same everything everywhere.** Both machines run the same `install.sh`, so they share the same
  shell, keys and Neovim.

## Shell basics this config gives you

| Key / command | What it does |
|---|---|
| `Ctrl-R` | fuzzy-search your shell history (fzf) |
| `Ctrl-T` | fuzzy-pick a file and insert its path |
| `Alt-C` | fuzzy-pick a directory and `cd` into it |
| `→` | accept the grey autosuggestion |
| `Ctrl-x Ctrl-e` | edit the current command in nvim (great for long one-liners) |
| `z proj` / `zi` | jump to a frequently used directory matching "proj" / pick one interactively (zoxide) |
| `lg` | lazygit |
| `gs`, `gd`, `gl` | git status / diff / short log graph |
| `ll` | detailed listing with git status (eza) |
| a leading space, e.g. `␣export TOKEN=...` | the command is not saved to history |

## Why plain zsh (no oh-my-zsh)

This is the common 2026 setup: plain zsh, a starship prompt, and two plugins from the package manager.
- **Fast**: a new shell starts in tens of milliseconds instead of a few hundred. You open many of them
  (Zellij panes, nvim terminals, SSH).
- **Readable**: `.zshrc` is about 100 commented lines of standard zsh, with no framework magic.
- **Portable**: starship looks the same on every machine, and in any shell.

## Migrating from the old chezmoi setup

Just run `./install.sh`.
- The files chezmoi had copied into place (`~/.zshrc`, `~/.config/nvim`, ...) are moved to a backup and
  replaced with links.
- `~/.oh-my-zsh` isn't used anymore. Delete it with `rm -rf ~/.oh-my-zsh` once you're happy.
- Optionally, remove chezmoi's leftover state with `chezmoi purge`.
