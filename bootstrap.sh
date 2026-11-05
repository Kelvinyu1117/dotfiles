#!/usr/bin/env bash
# Kept for old muscle memory: the real entry point is install.sh.
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/install.sh" "$@"
