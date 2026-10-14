#!/usr/bin/env bash
# Export only two single-file Actions artifacts; never modify the original checkpoint.
set -euo pipefail
: "${ROOTFS_SOURCE:?ROOTFS_SOURCE must name the existing ext4.zst image}"
: "${BOOT_BUILDER:?BOOT_BUILDER must point to the current boot-image script}"
: "${GITHUB_WORKSPACE:?}"
SOURCE="$(realpath "$ROOTFS_SOURCE")"
test -s "$SOURCE"
mkdir -p out
zstd --decompress --stdout "$SOURCE" > out/rootfs.ext4
test -s out/rootfs.ext4
test "$(blkid -p -o value -s TYPE out/rootfs.ext4)" = ext4

if [ -s out/boot-channel.img ]; then
  cp -f out/boot-channel.img out/boot.img
elif [ -s kernel-artifact/boot-channel.img ]; then
  cp -f kernel-artifact/boot-channel.img out/boot.img
else
  KERNEL=""
  DTB=""
  KREL=""
  for DIR in kernel-artifact kernel-local out; do
    test -d "$DIR" || continue
    if [ -s "$DIR/sdm632-motorola-channel.dtb" ]; then
      DTB="$DIR/sdm632-motorola-channel.dtb"
      if [ -s "$DIR/Image.gz" ]; then
        KERNEL="$DIR/Image.gz"
      else
        for CANDIDATE in "$DIR"/Image.gz-*; do
          if [ -s "$CANDIDATE" ]; then KERNEL="$CANDIDATE"; break; fi
        done
      fi
      if [ -s "$DIR/kernel-release.txt" ]; then
        KREL="$(cat "$DIR/kernel-release.txt")"
      fi
      if [ -n "$KERNEL" ] && [ -n "$KREL" ]; then break; fi
    fi
  done
  test -n "$KERNEL" && test -s "$KERNEL"
  test -n "$DTB" && test -s "$DTB"
  test -n "$KREL"
  MKBOOTIMG_REF=d3b6ee4295e1491432ce3d0fcfd53631177bbef4
  mkdir -p .rootfs-mkbootimg
  git -C .rootfs-mkbootimg init -q
  git -C .rootfs-mkbootimg remote add origin https://android.googlesource.com/platform/system/tools/mkbootimg
  git -C .rootfs-mkbootimg fetch -q --depth=1 origin "$MKBOOTIMG_REF"
  git -C .rootfs-mkbootimg checkout -q --detach FETCH_HEAD
  test "$(git -C .rootfs-mkbootimg rev-parse HEAD)" = "$MKBOOTIMG_REF"
  export MKBOOTIMG_PY="$PWD/.rootfs-mkbootimg/mkbootimg.py"
  export KERNEL_RELEASE="$KREL"
  export KERNEL_IMAGE="$PWD/$KERNEL"
  export CHANNEL_DTB="$PWD/$DTB"
  export CHANNEL_ROOT_DEVICE=PARTLABEL=userdata
  export OUT_DIR="$PWD/.rootfs-boot"
  mkdir -p "$OUT_DIR"
  bash "$BOOT_BUILDER"
  cp -f "$OUT_DIR/boot-channel.img" out/boot.img
fi
test -s out/boot.img
echo 'Ready: boot.img and rootfs.ext4; original complete rootfs artifact remains unchanged.'
