#!/usr/bin/env bash
# Install the exact Channel WCNSS firmware files into a target rootfs.
# The source must be supplied by the device owner; no Android partition mounts,
# proprietary firmware downloads or host package installations occur here.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE="${CHANNEL_FIRMWARE_DIR:-$ROOT/firmware/channel}"
ACTION="${1:-check}"
FILES=(wcnss.mdt wcnss.b00 wcnss.b01 wcnss.b02 wcnss.b04 wcnss.b06 wcnss.b09 wcnss.b10 wcnss.b11 wcnss.b12 WCNSS_qcom_wlan_nv.bin)
check() {
  local f missing=0
  for f in "${FILES[@]}"; do
    if [[ ! -s "$SOURCE/$f" ]]; then
      printf 'ERROR: Missing Channel Wi-Fi firmware: %s\n' "$SOURCE/$f" >&2
      missing=1
    fi
  done
  if ((missing)); then
    cat >&2 <<EOF
Wi-Fi firmware is REQUIRED. The build is stopped before rootfs generation.
Obtain original files from your own Moto G7 Play (channel):
  modem_a image/wcnss.mdt and image/wcnss.bXX
  vendor_a firmware/wlan/prima/WCNSS_qcom_wlan_nv.bin
Place them as regular files in: $SOURCE
Or set CHANNEL_FIRMWARE_DIR=/path/to/channel-firmware.
See FIRMWARE.md. No runtime modem/vendor mounts are used.
EOF
    return 1
  fi
  printf 'Channel WCNSS firmware verified: %s (11 files)\n' "$SOURCE"
}
case "$ACTION" in
  check) check ;;
  install)
    [[ $# -eq 2 && -n "${2:-}" && "$2" != / ]] || { echo 'Usage: channel.sh install TARGET_ROOTFS' >&2; exit 2; }
    check
    DEST="$2/lib/firmware"
    # Always dereference source symlinks; final rootfs contains regular firmware files.
    sudo mkdir -p "$DEST/wlan/prima" "$DEST/qcom/msm8953/motorola/channel"
    for f in wcnss.mdt wcnss.b00 wcnss.b01 wcnss.b02 wcnss.b04 wcnss.b06 wcnss.b09 wcnss.b10 wcnss.b11 wcnss.b12; do
      sudo install -m 0644 -D "$(realpath "$SOURCE/$f")" "$DEST/$f"
    done
    sudo install -m 0644 -D "$(realpath "$SOURCE/WCNSS_qcom_wlan_nv.bin")" "$DEST/wlan/prima/WCNSS_qcom_wlan_nv.bin"
    sudo install -m 0644 -D "$(realpath "$SOURCE/WCNSS_qcom_wlan_nv.bin")" "$DEST/qcom/msm8953/motorola/channel/WCNSS_qcom_wlan_nv.bin"
    # Check real file bytes are present at the paths requested by the kernel.
    for f in wcnss.mdt wcnss.b00 wcnss.b01 wcnss.b02 wcnss.b04 wcnss.b06 wcnss.b09 wcnss.b10 wcnss.b11 wcnss.b12; do
      sudo test -s "$DEST/$f"
    done
    sudo cmp "$SOURCE/WCNSS_qcom_wlan_nv.bin" "$DEST/qcom/msm8953/motorola/channel/WCNSS_qcom_wlan_nv.bin"
    sudo cmp "$SOURCE/WCNSS_qcom_wlan_nv.bin" "$DEST/wlan/prima/WCNSS_qcom_wlan_nv.bin"
    printf 'Installed Channel WCNSS firmware into target: %s\n' "$DEST"
    ;;
  *) echo 'Usage: channel.sh check | install TARGET_ROOTFS' >&2; exit 2 ;;
esac
