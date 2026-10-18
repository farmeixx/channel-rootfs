#!/usr/bin/env bash
# Generic source checkout / kernel build / boot image / checkpoint pipeline.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF="${KERNEL_MAINLINE_CONF:-$ROOT/mainline.conf}"
test -s "$CONF" || { echo "Missing mainline.conf: $CONF" >&2; exit 1; }
export KERNEL_MAINLINE_CONF="$CONF"
source "$CONF"
: "${KERNEL_URL:?set KERNEL_URL}"
: "${KERNEL_REF:?set KERNEL_REF}"
: "${KERNEL_CLONE_DIR:?set KERNEL_CLONE_DIR}"
: "${KERNEL_MKBOOTIMG_URL:?set KERNEL_MKBOOTIMG_URL}"
: "${KERNEL_MKBOOTIMG_REF:?set KERNEL_MKBOOTIMG_REF}"

source "$ROOT/scripts/host-deps.sh"
install_host_deps kernel
WORK="$ROOT/.work/kernel"
KERNEL_DIR="$(realpath -m "$ROOT/$KERNEL_CLONE_DIR")"
# Clone location is configurable, but never allow rm -rf outside .work.
case "$KERNEL_DIR" in "$ROOT/.work/"*) ;; *) echo "KERNEL_CLONE_DIR must be under .work/" >&2; exit 1 ;; esac
MKBOOT_DIR="$WORK/aosp-mkbootimg"
STAGING="$ROOT/out/kernel/.checkpoint-staging"
CHECKPOINT="$ROOT/out/kernel/checkpoint"
IMAGES="$ROOT/out/kernel/images"
mkdir -p "$WORK" "$ROOT/out/kernel"
CCACHE_BIN_DIR="$WORK/ccache-bin"
mkdir -p "$CCACHE_BIN_DIR"
ln -sfn "$(command -v ccache)" "$CCACHE_BIN_DIR/${KERNEL_CROSS_COMPILE}gcc"
export PATH="$CCACHE_BIN_DIR:$PATH"
echo "ccache active for ${KERNEL_CROSS_COMPILE}gcc"
rm -rf "$KERNEL_DIR" "$STAGING"
mkdir -p "$STAGING"

SOURCE_SHA="$(git ls-remote "$KERNEL_URL" "refs/heads/$KERNEL_REF" | awk 'NR==1 {print $1}')"
test -n "$SOURCE_SHA" || { echo "Kernel ref unavailable: $KERNEL_REF" >&2; exit 1; }
git clone --depth=1 --branch "$KERNEL_REF" "$KERNEL_URL" "$KERNEL_DIR"
test "$(git -C "$KERNEL_DIR" rev-parse HEAD)" = "$SOURCE_SHA" || {
  echo 'Kernel ref advanced while cloning; retry the build' >&2; exit 1;
}
printf 'kernel_url=%s\nkernel_ref=%s\nkernel_source_sha=%s\n' \
  "$KERNEL_URL" "$KERNEL_REF" "$SOURCE_SHA" > "$STAGING/source-report.txt"
export KERNEL_DIR OUT_DIR="$STAGING"
bash "$ROOT/mainline/build.sh"
KREL="$(cat "$STAGING/kernel-release.txt")"
DTB_NAME="${KERNEL_DTB##*/}"
{
  printf 'kernel_config_1=%s\nkernel_config_2=%s\n' "${KERNEL_CONFIG_1:-}" "${KERNEL_CONFIG_2:-}"
  for f in "$STAGING"/config-fragment-*.config; do
    [ -f "$f" ] || continue
    printf '%s_sha256=%s\n' "${f##*/}" "$(sha256sum "$f" | cut -d' ' -f1)"
  done
} >> "$STAGING/source-report.txt"

if [ ! -s "$MKBOOT_DIR/mkbootimg.py" ] || \
   [ "$(git -C "$MKBOOT_DIR" rev-parse HEAD 2>/dev/null || true)" != "$KERNEL_MKBOOTIMG_REF" ]; then
  rm -rf "$MKBOOT_DIR"
  git init -q "$MKBOOT_DIR"
  git -C "$MKBOOT_DIR" remote add origin "$KERNEL_MKBOOTIMG_URL"
  git -C "$MKBOOT_DIR" fetch --depth=1 origin "$KERNEL_MKBOOTIMG_REF"
  git -C "$MKBOOT_DIR" checkout -q --detach FETCH_HEAD
fi
test "$(git -C "$MKBOOT_DIR" rev-parse HEAD)" = "$KERNEL_MKBOOTIMG_REF"
python3 "$MKBOOT_DIR/mkbootimg.py" --help >/dev/null
python3 "$MKBOOT_DIR/unpack_bootimg.py" --help >/dev/null
export KERNEL_RELEASE="$KREL" KERNEL_IMAGE="$STAGING/Image.gz" \
  KERNEL_DTB_FILE="$STAGING/$DTB_NAME" MKBOOTIMG_PY="$MKBOOT_DIR/mkbootimg.py"
bash "$ROOT/mainline/build-bootimg.sh"

grep -Fq "root=$KERNEL_ROOT_DEVICE" "$STAGING/kernel-cmdline.txt" || {
  echo "Boot cmdline root does not match KERNEL_ROOT_DEVICE" >&2; exit 1;
}
UNPACKED="$WORK/unpacked-boot"
rm -rf "$UNPACKED"
python3 "$MKBOOT_DIR/unpack_bootimg.py" --boot_img "$STAGING/$KERNEL_BOOT_NAME" --out "$UNPACKED"
test -s "$UNPACKED/kernel"
test ! -s "$UNPACKED/ramdisk"
printf 'root_device=%s\n' "$KERNEL_ROOT_DEVICE" >> "$STAGING/kernel-info.txt"
cp "$CONF" "$STAGING/mainline.conf"
(
  cd "$STAGING"
  files=("$KERNEL_BOOT_NAME" Image.gz Image.gz-dtb "$DTB_NAME" kernel.config \
    mainline.conf System.map kernel-release.txt kernel-modules-*.tar.zst)
  for f in config-fragment-*.config; do
    [ -f "$f" ] && files+=("$f")
  done
  sha256sum "${files[@]}" > SHA256SUMS
)
KERNEL_CHECKPOINT_DIR="$STAGING" bash "$ROOT/scripts/kernel/validate.sh" --full

PREVIOUS="$ROOT/out/kernel/.checkpoint-previous"
rm -rf "$PREVIOUS"
if [ -d "$CHECKPOINT" ]; then mv "$CHECKPOINT" "$PREVIOUS"; fi
if ! mv "$STAGING" "$CHECKPOINT"; then
  [ ! -d "$PREVIOUS" ] || mv "$PREVIOUS" "$CHECKPOINT"
  echo 'Unable to publish kernel checkpoint' >&2
  exit 1
fi
mkdir -p "$IMAGES"
cp -f "$CHECKPOINT/$KERNEL_BOOT_NAME" "$IMAGES/boot.img"
cp -f "$CHECKPOINT/$KERNEL_BOOT_NAME" "$IMAGES/$KERNEL_BOOT_NAME"
rm -rf "$PREVIOUS"
printf '\nKernel build complete: %s\n' "$KREL"
ccache --show-stats
