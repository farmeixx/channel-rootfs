#!/usr/bin/env bash
# Kernel orchestrator: conf-driven, zero validation layers. Builds the mainline
# kernel from persistent local sources and publishes the reusable checkpoint
# (kernel, modules, boot image, config) consumed by every rootfs build.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE="$ROOT/cache"
SOURCES="$ROOT/sources"
BUILDS="$ROOT/build"
CHECKPOINT="$CACHE/mainline/checkpoint"
MODULE_CACHE="$CACHE/mainline/modules"
export LC_ALL=C

if [ "${1:-}" = --help ] || [ "${1:-}" = -h ]; then
  cat <<EOF
Usage: bash sh/run.sh

Builds the mainline kernel (clone on first use; ccache persistent) and
publishes cache/mainline/checkpoint plus a dated copy under build/mainline/.
To update the kernel source manually: git -C sources/linux pull --ff-only
EOF
  exit 0
fi

# The customization surface: device identity, build knobs, release label and
# the device kernel config. Empty values keep built-in runtime defaults.
source "$ROOT/conf/device.conf"
source "$ROOT/conf/build.conf"
source "$ROOT/conf/kernel.conf"
CONF_PATH="${KERNEL_MAINLINE_CONF:-$ROOT/conf/mainline.conf}"
source "$CONF_PATH"

say() { printf '\n[%s] %s\n' "$DEVICE" "$*"; }
die() { printf '\nERROR [%s]: %s\n' "$DEVICE" "$*" >&2; exit 1; }

# The build stage runs as a child process: broadcast the knobs it consumes.
export DEVICE JOBS KERNEL_LOCALVERSION MODULES_ARCHIVE_BASE

# Build host dependencies and the persistent compiler cache.
source "$ROOT/sh/deps.sh"
install_host_deps kernel
export CCACHE_DIR="$CACHE/mainline/ccache" CCACHE_MAXSIZE="${CCACHE_MAXSIZE:-2G}" CCACHE_COMPRESS="${CCACHE_COMPRESS:-true}"
mkdir -p "$CCACHE_DIR" "$MODULE_CACHE" "$BUILDS/mainline" "$CACHE/mainline"
ccache --max-size "$CCACHE_MAXSIZE"
CCACHE_BIN="$CCACHE_DIR-bin"
mkdir -p "$CCACHE_BIN"
ln -sfn "$(command -v ccache)" "$CCACHE_BIN/${KERNEL_CROSS_COMPILE}gcc"
export PATH="$CCACHE_BIN:$PATH"

# Persistent kernel source checkout: cloned once, then kept between builds.
# Updating it is a manual step: git -C sources/linux pull --ff-only
KERNEL_DIR="$SOURCES/linux"
if [ ! -d "$KERNEL_DIR/.git" ]; then
  say "Cloning kernel sources once; next builds keep the checkout."
  GIT_TERMINAL_PROMPT=0 git clone --depth=1 --single-branch --branch "$KERNEL_REF" "$KERNEL_URL" "$KERNEL_DIR"
fi
SOURCE_SHA="$(git -C "$KERNEL_DIR" rev-parse HEAD)"

# Pinned AOSP mkbootimg checkout: fetched once at the configured commit.
MKBOOT_DIR="$SOURCES/mkbootimg"
if [ ! -s "$MKBOOT_DIR/mkbootimg.py" ]; then
  rm -rf "$MKBOOT_DIR"
  mkdir -p "$MKBOOT_DIR"
  git -C "$MKBOOT_DIR" init -q
  git -C "$MKBOOT_DIR" remote add origin "$KERNEL_MKBOOTIMG_URL"
  GIT_TERMINAL_PROMPT=0 git -C "$MKBOOT_DIR" fetch --depth=1 origin "$KERNEL_MKBOOTIMG_REF"
  git -C "$MKBOOT_DIR" checkout --detach -q FETCH_HEAD
fi

STAGE="$CACHE/mainline/.checkpoint-staging"
PREV="$CACHE/mainline/.checkpoint-previous"
rm -rf "$STAGE"
mkdir -p "$STAGE"
export OUT_DIR="$STAGE" KERNEL_DIR
say "Compiling $DEVICE kernel at $SOURCE_SHA with ccache"
bash "$ROOT/sh/build.sh"
KREL="$(cat "$STAGE/kernel-release.txt")"

# Pack the Android boot image from the built payload.
export KERNEL_RELEASE="$KREL" KERNEL_IMAGE="$STAGE/Image.gz" \
  KERNEL_DTB_FILE="$STAGE/${KERNEL_DTB##*/}" MKBOOTIMG_PY="$MKBOOT_DIR/mkbootimg.py"
bash "$ROOT/sh/bootimg.sh"

# Checkpoint metadata: the packaged identity every consumer trusts.
cp "$CONF_PATH" "$STAGE/mainline.conf"
printf 'root_device=%s\n' "$KERNEL_ROOT_DEVICE" >> "$STAGE/kernel-info.txt"
{
  printf 'kernel_url=%s\nkernel_ref=%s\nkernel_source_sha=%s\n' "$KERNEL_URL" "$KERNEL_REF" "$SOURCE_SHA"
  printf 'kernel_config_1=%s\nkernel_config_2=%s\n' "${KERNEL_CONFIG_1:-}" "${KERNEL_CONFIG_2:-}"
} > "$STAGE/source-report.txt"

# Dated build copy, independent from the reusable cached checkpoint.
STAMP="$(date -u +%Y%m%d%H%M%S)"
BASE="$DEVICE-mainline-$STAMP"
DEST="$BUILDS/mainline"
ARCHIVE="$STAGE/${MODULES_ARCHIVE_BASE:-kernel-modules}-$KREL.tar.zst"
cp "$STAGE/$KERNEL_BOOT_NAME"  "$DEST/$BASE.img"
cp "$STAGE/${KERNEL_DTB##*/}"  "$DEST/$BASE.dtb"
cp "$STAGE/Image.gz"           "$DEST/$BASE.Image.gz"
cp "$STAGE/kernel.config"      "$DEST/$BASE.config"
cp "$STAGE/System.map"         "$DEST/$BASE.System.map"
cp "$ARCHIVE"                  "$DEST/$BASE.modules.tar.zst"
cp "$STAGE/kernel-info.txt"    "$DEST/$BASE.kernel-info.txt"
cp "$STAGE/kernel-cmdline.txt" "$DEST/$BASE.kernel-cmdline.txt"
cp "$STAGE/source-report.txt"  "$DEST/$BASE.source-report.txt"
(cd "$DEST" && sha256sum "$BASE.img" "$BASE.dtb" "$BASE.Image.gz" "$BASE.config" "$BASE.System.map" "$BASE.modules.tar.zst" "$BASE.kernel-info.txt" "$BASE.kernel-cmdline.txt" "$BASE.source-report.txt" > "$BASE.SHA256SUMS")

# Module set published separately, keyed by source sha and release.
MOD_PATH="$MODULE_CACHE/$SOURCE_SHA/$KREL"
mkdir -p "$MOD_PATH"
cp "$ARCHIVE" "$MOD_PATH/${MODULES_ARCHIVE_BASE:-kernel-modules}-$KREL.tar.zst.tmp"
mv -f "$MOD_PATH/${MODULES_ARCHIVE_BASE:-kernel-modules}-$KREL.tar.zst.tmp" "$MOD_PATH/${MODULES_ARCHIVE_BASE:-kernel-modules}-$KREL.tar.zst"

# Publish the reusable checkpoint (previous one kept until the swap completes).
rm -rf "$PREV"
if [ -d "$CHECKPOINT" ]; then mv "$CHECKPOINT" "$PREV"; fi
if ! mv "$STAGE" "$CHECKPOINT"; then
  if [ -d "$PREV" ]; then mv "$PREV" "$CHECKPOINT"; fi
  die 'Failed to publish the kernel checkpoint.'
fi
rm -rf "$PREV"
printf '%s\n' "$MOD_PATH/${MODULES_ARCHIVE_BASE:-kernel-modules}-$KREL.tar.zst" > "$MODULE_CACHE/current.txt"

say "Kernel ready: $DEST/$BASE.img"
say "Modules archive: $MOD_PATH/${MODULES_ARCHIVE_BASE:-kernel-modules}-$KREL.tar.zst"
ccache --show-stats
