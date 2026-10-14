#!/usr/bin/env bash
# Only fetch an existing successful, unexpired mainline kernel checkpoint.
# Never launch or build the kernel from any rootfs workflow.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DISTRO="${1:?Usage: bash scripts/ci/build-rootfs.sh alpine|debian|ubuntu}"
case "$DISTRO" in alpine|debian|ubuntu);; *) echo "Invalid distro: $DISTRO" >&2; exit 2;; esac
if [ "${GITHUB_ACTIONS:-}" = true ]; then
  bash "$ROOT/scripts/ci/fetch-kernel.sh"
fi
exec bash "$ROOT/$DISTRO/run.sh"
