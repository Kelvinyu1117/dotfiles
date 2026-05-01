#!/usr/bin/env bash
# bootstrap.sh — dispatcher
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$(uname -s)" in
  Linux)  bash "$SCRIPT_DIR/scripts/bootstrap-linux-ubuntu.sh" "$@" ;;
  Darwin) bash "$SCRIPT_DIR/scripts/bootstrap-macos.sh"        "$@" ;;
  *) echo "Unsupported OS" >&2; exit 1 ;;
esac

echo "Bootstrap completed successfully."

