#!/bin/bash
set -euo pipefail

os=$(uname -s)
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() {
  echo "[bootstrap] $*"
}

file_exists() {
  [[ -f "$1" ]]
}

case "$os" in
  Darwin)
    log "macOS detected: running bootstrap-mac.sh"
    if file_exists "$script_dir/bootstrap-mac.sh"; then
      "$script_dir/bootstrap-mac.sh"
    else
      echo "Error: bootstrap-mac.sh not found!"
      exit 1
    fi
    ;;
  Linux)
    log "Linux detected: running bootstrap-linux.sh"
    if file_exists "$script_dir/bootstrap-linux.sh"; then
      "$script_dir/bootstrap-linux.sh"
    else
      echo "Error: bootstrap-linux.sh not found!"
      exit 1
    fi
    ;;
  *)
    echo "Unsupported OS: $os"
    exit 1
    ;;
esac

log "Bootstrap completed successfully."

