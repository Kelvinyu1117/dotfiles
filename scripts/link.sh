#!/bin/sh
# Symlink every file under home/ to the same path under $HOME.
#
#   home/.zshrc                     -> ~/.zshrc
#   home/.config/zellij/config.kdl  -> ~/.config/zellij/config.kdl
#
# Files are linked one by one (not whole folders), so apps can still create their own files next
# to them without those ending up in the repo. Anything already at a target path is moved to
# ~/.dotfiles-backup/<timestamp>/ first. Safe to re-run.
#
#   scripts/link.sh            link everything
#   scripts/link.sh --dry-run  only print what would happen
set -eu

DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

REPO=$(cd "$(dirname "$0")/.." && pwd)
SRC="$REPO/home"
BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

linked=0
unchanged=0
backed_up=0

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "would: $*"
  else
    "$@"
  fi
}

# `find -print` + `read` handles spaces in names; dotfiles never contain newlines.
cd "$SRC"
find . -type f -print | sed 's|^\./||' | sort | {
  while IFS= read -r rel; do
    src="$SRC/$rel"
    dst="$HOME/$rel"

    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
      unchanged=$((unchanged + 1))
      continue
    fi

    if [ -e "$dst" ] || [ -L "$dst" ]; then
      run mkdir -p "$(dirname "$BACKUP/$rel")"
      run mv "$dst" "$BACKUP/$rel"
      echo "backed up ~/$rel -> ${BACKUP#"$HOME"/}/$rel"
      backed_up=$((backed_up + 1))
    fi

    run mkdir -p "$(dirname "$dst")"
    run ln -s "$src" "$dst"
    echo "linked    ~/$rel"
    linked=$((linked + 1))
  done
  echo "links: $linked new, $unchanged unchanged, $backed_up backed up"
}
