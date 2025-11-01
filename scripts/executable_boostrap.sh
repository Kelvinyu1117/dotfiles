#!/bin/bash
set -e

os=$(uname -s)
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$os" in
  Darwin)
    echo "macOS detected: running bootstrap-mac.sh"
    "$script_dir/bootstrap-mac.sh"
    ;;
  Linux)
    echo "Linux detected: running bootstrap-linux.sh"
    "$script_dir/bootstrap-linux.sh"
    ;;
  *)
    echo "Unsupported OS: $os"
    exit 1
    ;;
esac

