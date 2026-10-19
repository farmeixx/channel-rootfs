#!/usr/bin/env bash
# Verify embedded ELF module vermagic, not just the parent /lib/modules/ folder.
set -euo pipefail
ARCHIVE="${1:?Usage: check-modules.sh ARCHIVE KERNEL_RELEASE}"
KREL="${2:?Usage: check-modules.sh ARCHIVE KERNEL_RELEASE}"
[[ "$KREL" =~ ^[-A-Za-z0-9._+]+$ ]] || { echo "Invalid kernel release: $KREL" >&2; exit 1; }
test -s "$ARCHIVE" || { echo "Missing module archive: $ARCHIVE" >&2; exit 1; }
command -v zstd >/dev/null || { echo 'zstd is required for module validation' >&2; exit 1; }

BASE="lib/modules/$KREL/kernel"
MODULES=(
  "$BASE/drivers/usb/gadget/libcomposite.ko"
  "$BASE/drivers/net/wireless/ath/wcn36xx/wcn36xx.ko"
)
TEMP="$(mktemp -d)"
trap 'rm -rf "$TEMP"' EXIT
if ! tar -I zstd -xf "$ARCHIVE" -C "$TEMP" "${MODULES[@]}"; then
  echo "Kernel archive is missing Channel's required USB/Wi-Fi modules" >&2
  exit 1
fi
for module in "${MODULES[@]}"; do
  test -s "$TEMP/$module" || { echo "Missing module: $module" >&2; exit 1; }
  VERMAGIC="$(LC_ALL=C tr '\000' '\n' < "$TEMP/$module" |
    awk '/^vermagic=/ { sub(/^vermagic=/, ""); print; found=1 } END { if (!found) exit 1 }')" || {
      echo "No ELF vermagic metadata in $module" >&2; exit 1;
    }
  case "$VERMAGIC" in
    "$KREL "*) echo "Verified module release: $module -> $KREL" ;;
    *) echo "KERNEL/ROOTFS RELEASE MISMATCH: $module" >&2
       echo "  checkpoint release: $KREL" >&2
       echo "  embedded vermagic: $VERMAGIC" >&2
       exit 1 ;;
  esac
done
