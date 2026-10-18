#!/usr/bin/env bash
# Compatibility entrypoint for existing Channel scripts.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
exec bash "$ROOT/scripts/firmware/install.sh" "$@"
