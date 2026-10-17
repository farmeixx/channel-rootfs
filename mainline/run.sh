#!/usr/bin/env bash
# Complete local/CI kernel build. Original kernel build.sh remains responsible
# for configuring and compiling the kernel, DTB and modules.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/host-deps.sh"
install_host_deps kernel

KERNEL_URL="${KERNEL_URL:-https://gitlab.com/vanadium-oss/motorola-msm8953/mainline/linux.git}"
KERNEL_REF="${KERNEL_REF:-msm8953/latest}"
MKBOOTIMG_URL="${MKBOOTIMG_URL:-https://android.googlesource.com/platform/system/tools/mkbootimg}"
MKBOOTIMG_REF="${MKBOOTIMG_REF:-d3b6ee4295e1491432ce3d0fcfd53631177bbef4}"
WORK="$ROOT/.work/kernel"
KERNEL_DIR="$WORK/source"
MKBOOT_DIR="$WORK/aosp-mkbootimg"
STAGING="$ROOT/out/kernel/.checkpoint-staging"
CHECKPOINT="$ROOT/out/kernel/checkpoint"
IMAGES="$ROOT/out/kernel/images"
mkdir -p "$WORK" "$ROOT/out/kernel"
# Cache ARM64 GCC compilation without wrapping binutils or changing Kbuild flags.
CCACHE_BIN_DIR="$WORK/ccache-bin"
mkdir -p "$CCACHE_BIN_DIR"
ln -sfn "$(command -v ccache)" "$CCACHE_BIN_DIR/aarch64-linux-gnu-gcc"
export PATH="$CCACHE_BIN_DIR:$PATH"
echo "ccache enabled for aarch64-linux-gnu-gcc"
rm -rf "$KERNEL_DIR" "$STAGING"
mkdir -p "$STAGING"

SOURCE_SHA="$(git ls-remote "$KERNEL_URL" "refs/heads/$KERNEL_REF" | awk 'NR==1 {print $1}')"
[ -n "$SOURCE_SHA" ] || { echo "ERROR: Kernel branch unavailable: $KERNEL_REF" >&2; exit 1; }
git clone --depth=1 --branch "$KERNEL_REF" "$KERNEL_URL" "$KERNEL_DIR"
[ "$(git -C "$KERNEL_DIR" rev-parse HEAD)" = "$SOURCE_SHA" ] || {
  echo 'ERROR: Kernel source branch changed while cloning; retry explicitly.' >&2; exit 1;
}
[ -s "$KERNEL_DIR/arch/arm64/boot/dts/qcom/sdm632-motorola-channel.dts" ] || {
  echo 'ERROR: Channel device-tree source is missing.' >&2; exit 1;
}
printf 'kernel_url=%s\nkernel_ref=%s\nkernel_source_sha=%s\n' "$KERNEL_URL" "$KERNEL_REF" "$SOURCE_SHA" > "$STAGING/source-report.txt"
export KERNEL_DIR OUT_DIR="$STAGING"
bash "$ROOT/mainline/build.sh"
KREL="$(cat "$STAGING/kernel-release.txt")"

# Prepare the identical, pinned AOSP mkbootimg revision as the old workflow.
if [ ! -s "$MKBOOT_DIR/mkbootimg.py" ] || \
   [ "$(git -C "$MKBOOT_DIR" rev-parse HEAD 2>/dev/null || true)" != "$MKBOOTIMG_REF" ]; then
  rm -rf "$MKBOOT_DIR"
  git init -q "$MKBOOT_DIR"
  git -C "$MKBOOT_DIR" remote add origin "$MKBOOTIMG_URL"
  git -C "$MKBOOT_DIR" fetch --depth=1 origin "$MKBOOTIMG_REF"
  git -C "$MKBOOT_DIR" checkout -q --detach FETCH_HEAD
fi
[ "$(git -C "$MKBOOT_DIR" rev-parse HEAD)" = "$MKBOOTIMG_REF" ] || { echo 'ERROR: mkbootimg revision mismatch.' >&2; exit 1; }
python3 "$MKBOOT_DIR/mkbootimg.py" --help >/dev/null
python3 "$MKBOOT_DIR/unpack_bootimg.py" --help >/dev/null
export KERNEL_RELEASE="$KREL" KERNEL_IMAGE="$STAGING/Image.gz"
export CHANNEL_DTB="$STAGING/sdm632-motorola-channel.dtb"
export CHANNEL_ROOT_DEVICE="${CHANNEL_ROOT_DEVICE:-PARTLABEL=userdata}"
export MKBOOTIMG_PY="$MKBOOT_DIR/mkbootimg.py"
bash "$ROOT/mainline/build-bootimg.sh"
grep -Fq "root=$CHANNEL_ROOT_DEVICE" "$STAGING/kernel-cmdline.txt"
grep -Fq 'rootfstype=ext4' "$STAGING/kernel-cmdline.txt"
grep -Fq 'rootwait' "$STAGING/kernel-cmdline.txt"
! grep -Fq 'rdinit=/init' "$STAGING/kernel-cmdline.txt"
UNPACKED="$WORK/unpacked-boot"
rm -rf "$UNPACKED"
python3 "$MKBOOT_DIR/unpack_bootimg.py" --boot_img "$STAGING/boot-channel.img" --out "$UNPACKED"
[ -s "$UNPACKED/kernel" ] && [ ! -s "$UNPACKED/ramdisk" ] || { echo 'ERROR: Boot image was not created correctly.' >&2; exit 1; }
printf 'root_device=%s\n' "$CHANNEL_ROOT_DEVICE" >> "$STAGING/kernel-info.txt"
(
  cd "$STAGING"
  sha256sum boot-channel.img Image.gz Image.gz-dtb sdm632-motorola-channel.dtb \
    kernel.config System.map kernel-release.txt kernel-modules-*.tar.zst > SHA256SUMS
)
# Verify the complete new checkpoint BEFORE replacing an older valid one.
KERNEL_CHECKPOINT_DIR="$STAGING" bash "$ROOT/scripts/kernel/validate.sh" --full
# Atomically publish within the same filesystem. Preserve previous contents
# if the final rename fails.
PREVIOUS="$ROOT/out/kernel/.checkpoint-previous"
rm -rf "$PREVIOUS"
if [ -d "$CHECKPOINT" ]; then mv "$CHECKPOINT" "$PREVIOUS"; fi
if ! mv "$STAGING" "$CHECKPOINT"; then
  if [ -d "$PREVIOUS" ]; then mv "$PREVIOUS" "$CHECKPOINT"; fi
  echo 'ERROR: Unable to publish new checkpoint.' >&2
  exit 1
fi
mkdir -p "$IMAGES"
cp -f "$CHECKPOINT/boot-channel.img" "$IMAGES/boot.img"
cp -f "$CHECKPOINT/boot-channel.img" "$IMAGES/boot-channel.img"
rm -rf "$PREVIOUS"
printf '\nKernel build complete.\n  Checkpoint: %s\n  boot.img:   %s\n' "$CHECKPOINT" "$IMAGES/boot.img"
ccache --show-stats
