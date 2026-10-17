#!/usr/bin/env bash
# Prefer verified Channel GitLab firmware; retain a verified offline fallback.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUNDLED="$ROOT/firmware/channel"
MANIFEST="$BUNDLED/SHA256SUMS"
SOURCE="$BUNDLED"
ACTION="${1:-check}"
FW=(wcnss.mdt wcnss.b00 wcnss.b01 wcnss.b02 wcnss.b04 wcnss.b09 wcnss.b10 wcnss.b11 wcnss.b12)
NV=WCNSS_qcom_wlan_nv.bin
PARTS=(wcnss.b06.xz.part00 wcnss.b06.xz.part01 wcnss.b06.xz.part02)
B06_HASH=f83da41610b4b2b24e176b4536bfe6c4f8fca7d46d5a0cc7694ba12e89213376

verify_source() {
  local candidate="$1" f got
  test -s "$MANIFEST" || return 1
  for f in "${FW[@]}" "${PARTS[@]}" "$NV"; do
    test -s "$candidate/$f" || return 1
  done
  (cd "$candidate" && sha256sum -c --status "$MANIFEST") || return 1
  command -v xz >/dev/null || return 1
  got="$(cat "${PARTS[@]/#/$candidate/}" | xz -dc | sha256sum | cut -d ' ' -f1)" || return 1
  [ "$got" = "$B06_HASH" ] || return 1
}

try_gitlab() {
  command -v git >/dev/null && command -v timeout >/dev/null || return 1
  local checkout="$ROOT/.work/firmware/channel-gitlab"
  local staged="$ROOT/.work/firmware/channel-gitlab-selected"
  local url="${CHANNEL_FIRMWARE_URL:-https://gitlab.com/vanadium-oss/motorola-msm8953/mainline/channel-firmware.git}"
  local ref="${CHANNEL_FIRMWARE_REF:-}"
  local dir f nv
  if [ ! -d "$checkout/.git" ]; then
    mkdir -p "$(dirname "$checkout")"
    rm -rf "$checkout"
    if [ -n "$ref" ]; then
      GIT_TERMINAL_PROMPT=0 timeout 35s git clone -q --depth 1 --branch "$ref" "$url" "$checkout" || return 1
    else
      GIT_TERMINAL_PROMPT=0 timeout 35s git clone -q --depth 1 "$url" "$checkout" || return 1
    fi
  fi
  for dir in "$checkout/wlan/wcnss" "$checkout/wcnss" "$checkout/firmware/channel"; do
    [ -s "$dir/wcnss.mdt" ] || continue
    rm -rf "$staged"
    mkdir -p "$staged"
    for f in "${FW[@]}" "${PARTS[@]}"; do
      [ -s "$dir/$f" ] && ln -s "$dir/$f" "$staged/$f"
    done
    for nv in "$checkout/wlan/$NV" "$dir/$NV"; do
      if [ -s "$nv" ]; then ln -s "$nv" "$staged/$NV"; break; fi
    done
    if verify_source "$staged"; then
      SOURCE="$staged"
      echo "Using verified Channel firmware from GitLab ($(git -C "$checkout" rev-parse --short HEAD))."
      return 0
    fi
  done
  return 1
}

check() {
  case "${CHANNEL_FIRMWARE_SOURCE:-auto}" in
    auto)
      if try_gitlab; then return 0; fi
      verify_source "$BUNDLED" || {
        echo 'ERROR: GitLab WCNSS incomplete/unavailable and verified bundled firmware missing.' >&2
        return 1
      }
      SOURCE="$BUNDLED"
      echo 'Using verified bundled WCNSS firmware (GitLab does not provide a complete matching set yet).'
      ;;
    gitlab)
      try_gitlab || {
        echo 'ERROR: GitLab firmware missing, inaccessible, or SHA256 differs from the known-good Channel set.' >&2
        return 1
      }
      ;;
    bundled)
      verify_source "$BUNDLED" || { echo 'ERROR: bundled WCNSS firmware failed verification.' >&2; return 1; }
      SOURCE="$BUNDLED"
      ;;
    *)
      echo 'ERROR: CHANNEL_FIRMWARE_SOURCE must be auto, gitlab, or bundled.' >&2
      return 2
      ;;
  esac
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
    # Restore the verified compressed WCNSS segment from the selected source.
    sudo install -m 0644 /dev/null "$DEST/wcnss.b06"
    cat "${PARTS[@]/#/$SOURCE/}" | xz -dc | sudo tee "$DEST/wcnss.b06" >/dev/null
    [ "$(sudo sha256sum "$DEST/wcnss.b06" | cut -d ' ' -f1)" = "$B06_HASH" ] || { echo 'ERROR: wrong wcnss.b06 bytes in rootfs.' >&2; exit 1; }
    sudo install -m 0644 "$SOURCE/$NV" "$DEST/wlan/prima/$NV"
    sudo install -m 0644 "$SOURCE/$NV" "$DEST/qcom/msm8953/motorola/channel/$NV"
    sudo cmp "$SOURCE/$NV" "$DEST/wlan/prima/$NV"
    sudo cmp "$SOURCE/$NV" "$DEST/qcom/msm8953/motorola/channel/$NV"
    echo "Channel WCNSS firmware installed from $SOURCE into $DEST"
    ;;
  *) echo 'Usage: channel.sh check | install TARGET_ROOTFS' >&2; exit 2 ;;
esac
