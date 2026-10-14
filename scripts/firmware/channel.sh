#!/usr/bin/env bash
# Firmware is bundled with this Channel project: no download, no device mounts.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE="$ROOT/firmware/channel"
ACTION="${1:-check}"
FW=(wcnss.mdt wcnss.b00 wcnss.b01 wcnss.b02 wcnss.b04 wcnss.b09 wcnss.b10 wcnss.b11 wcnss.b12)
NV=WCNSS_qcom_wlan_nv.bin
PARTS=(wcnss.b06.xz.part00 wcnss.b06.xz.part01 wcnss.b06.xz.part02)
B06_HASH=f83da41610b4b2b24e176b4536bfe6c4f8fca7d46d5a0cc7694ba12e89213376
check() {
  local f
  for f in "${FW[@]}" "${PARTS[@]}" "$NV"; do
    test -s "$SOURCE/$f" || { echo "ERROR: bundled Channel firmware is missing: $SOURCE/$f" >&2; return 1; }
  done
  (cd "$SOURCE" && sha256sum -c --status SHA256SUMS) || {
    echo 'ERROR: Channel firmware does not match the verified firmware manifest.' >&2
    return 1
  }
  command -v xz >/dev/null || { echo 'ERROR: xz is needed to unpack the included WCNSS firmware.' >&2; return 1; }
  local got
  got="$(cat "${PARTS[@]/#/$SOURCE/}" | xz -dc | sha256sum | cut -d ' ' -f1)"
  [ "$got" = "$B06_HASH" ] || { echo 'ERROR: wcnss.b06 reconstructed hash mismatch.' >&2; return 1; }
  echo 'Bundled Channel WCNSS firmware verified.' 
}
case "$ACTION" in
  check) check ;;
  install)
    [ "$#" -eq 2 ] && [ -n "$2" ] && [ "$2" != / ] || { echo 'Usage: channel.sh install TARGET_ROOTFS' >&2; exit 2; }
    check
    DEST="$2/lib/firmware"
    sudo mkdir -p "$DEST/wlan/prima" "$DEST/qcom/msm8953/motorola/channel"
    for f in "${FW[@]}"; do
      sudo install -m 0644 "$SOURCE/$f" "$DEST/$f"
    done
    # Restore the large segment from bundled xz parts; nothing is downloaded.
    sudo install -m 0644 /dev/null "$DEST/wcnss.b06"
    cat "${PARTS[@]/#/$SOURCE/}" | xz -dc | sudo tee "$DEST/wcnss.b06" >/dev/null
    [ "$(sudo sha256sum "$DEST/wcnss.b06" | cut -d ' ' -f1)" = "$B06_HASH" ] || { echo 'ERROR: wrong wcnss.b06 bytes in rootfs.' >&2; exit 1; }
    sudo install -m 0644 "$SOURCE/$NV" "$DEST/wlan/prima/$NV"
    sudo install -m 0644 "$SOURCE/$NV" "$DEST/qcom/msm8953/motorola/channel/$NV"
    sudo cmp "$SOURCE/$NV" "$DEST/wlan/prima/$NV"
    sudo cmp "$SOURCE/$NV" "$DEST/qcom/msm8953/motorola/channel/$NV"
    echo "Channel WCNSS firmware installed into $DEST"
    ;;
  *) echo 'Usage: channel.sh check | install TARGET_ROOTFS' >&2; exit 2 ;;
esac
