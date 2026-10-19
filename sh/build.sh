#!/usr/bin/env bash
# Generic kernel builder: source, fragments, DTB and options are from mainline.conf.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${KERNEL_MAINLINE_CONF:-$ROOT/conf/mainline.conf}"
: "${KERNEL_DIR:?set KERNEL_DIR}"
: "${OUT_DIR:?set OUT_DIR}"
: "${KERNEL_ARCH:?set KERNEL_ARCH}"
: "${KERNEL_CROSS_COMPILE:?set KERNEL_CROSS_COMPILE}"
: "${KERNEL_BASE_CONFIG:?set KERNEL_BASE_CONFIG}"
: "${KERNEL_DTB:?set KERNEL_DTB}"
: "${KERNEL_IMAGE_TARGET:?set KERNEL_IMAGE_TARGET}"
: "${KERNEL_IMAGE_PATH:?set KERNEL_IMAGE_PATH}"

JOBS="${JOBS:-$(nproc)}"
mkdir -p "$OUT_DIR"
cd "$KERNEL_DIR"
MAKE=(make ARCH="$KERNEL_ARCH" CROSS_COMPILE="$KERNEL_CROSS_COMPILE")

echo "::group::Kernel configuration"
"${MAKE[@]}" "$KERNEL_BASE_CONFIG"
fragments=()
for fragment in "${KERNEL_CONFIG_1:-}" "${KERNEL_CONFIG_2:-}"; do
  [ -n "$fragment" ] || continue
  if [[ "$fragment" == repo:* ]]; then
    resolved="$ROOT/${fragment#repo:}"
  elif [[ "$fragment" = /* ]]; then
    resolved="$fragment"
  else
    resolved="$KERNEL_DIR/$fragment"
  fi
  test -s "$resolved" || { echo "Missing config fragment: $resolved" >&2; exit 1; }
  fragments+=("$resolved")
done
if [ "${#fragments[@]}" -gt 0 ]; then
  test -f scripts/kconfig/merge_config.sh || { echo "Missing merge_config.sh" >&2; exit 1; }
  ARCH="$KERNEL_ARCH" CROSS_COMPILE="$KERNEL_CROSS_COMPILE" \
    bash scripts/kconfig/merge_config.sh -m .config "${fragments[@]}"
fi
for sym in "${KERNEL_ENABLE_Y[@]}"; do scripts/config --enable "${sym#CONFIG_}"; done
for sym in "${KERNEL_ENABLE_M[@]}"; do scripts/config --module "${sym#CONFIG_}"; done
"${MAKE[@]}" olddefconfig
# Preserve explicit DWC3 gadget/dual-role check from the older builder.
if ! grep -qx 'CONFIG_USB_DWC3_DUAL_ROLE=y' .config &&
   ! grep -qx 'CONFIG_USB_DWC3_GADGET=y' .config; then
  echo "DWC3 has neither gadget nor dual-role mode enabled" >&2
  exit 1
fi

for sym in "${KERNEL_REQUIRE_Y[@]}" "${KERNEL_ENABLE_Y[@]}"; do
  test -n "$sym" || continue
  grep -qx "CONFIG_${sym#CONFIG_}=y" .config || {
    echo "Kernel config needs CONFIG_${sym#CONFIG_}=y" >&2; exit 1;
  }
done
for sym in "${KERNEL_REQUIRE_M[@]}" "${KERNEL_ENABLE_M[@]}"; do
  test -n "$sym" || continue
  grep -qx "CONFIG_${sym#CONFIG_}=m" .config || {
    echo "Kernel config needs CONFIG_${sym#CONFIG_}=m" >&2; exit 1;
  }
done
echo "::endgroup::"

KREL="$("${MAKE[@]}" -s kernelrelease)"
case "$KREL" in ""|*-dirty) echo "Invalid kernel release: $KREL" >&2; exit 1;; esac
echo "::group::Compile kernel"
"${MAKE[@]}" -j"$JOBS" "$KERNEL_IMAGE_TARGET" dtbs modules
echo "::endgroup::"

test -s "$KERNEL_DTB" || { echo "Missing requested DTB: $KERNEL_DTB" >&2; exit 1; }
test -s "$KERNEL_IMAGE_PATH"
test -s System.map
if [ -n "${KERNEL_DTB_CHECK_NODE:-}" ]; then
  test "$(fdtget -t s "$KERNEL_DTB" "$KERNEL_DTB_CHECK_NODE" "$KERNEL_DTB_CHECK_PROPERTY")" = "$KERNEL_DTB_CHECK_VALUE" || {
    echo "DTB validation failed: $KERNEL_DTB_CHECK_NODE" >&2; exit 1;
  }
fi
DTB_BASENAME="${KERNEL_DTB##*/}"
cp "$KERNEL_IMAGE_PATH" "$OUT_DIR/Image.gz"
cp "$KERNEL_IMAGE_PATH" "$OUT_DIR/Image.gz-$KREL"
cp "$KERNEL_DTB" "$OUT_DIR/$DTB_BASENAME"
if [ -n "${KERNEL_DTB_POSTPROCESS:-}" ]; then
  case "$KERNEL_DTB_POSTPROCESS" in
    repo:*) postprocess="$ROOT/${KERNEL_DTB_POSTPROCESS#repo:}" ;;
    /*) postprocess="$KERNEL_DTB_POSTPROCESS" ;;
    *) postprocess="$KERNEL_DIR/$KERNEL_DTB_POSTPROCESS" ;;
  esac
  test -s "$postprocess" || { echo "DTB postprocess script missing: $postprocess" >&2; exit 1; }
  bash "$postprocess" "$OUT_DIR/$DTB_BASENAME"
fi
cp .config "$OUT_DIR/kernel.config"
cp System.map "$OUT_DIR/System.map"
printf '%s\n' "$KREL" > "$OUT_DIR/kernel-release.txt"
git rev-parse HEAD > "$OUT_DIR/kernel-git-revision.txt"
cat "$OUT_DIR/Image.gz" "$OUT_DIR/$DTB_BASENAME" > "$OUT_DIR/Image.gz-dtb"

for idx in "${!fragments[@]}"; do
  cp "${fragments[$idx]}" "$OUT_DIR/config-fragment-$((idx + 1)).config"
done

echo "::group::Package modules"
rm -rf "$OUT_DIR/modules-root"
mkdir -p "$OUT_DIR/modules-root"
"${MAKE[@]}" KERNELRELEASE="$KREL" INSTALL_MOD_PATH="$OUT_DIR/modules-root" modules_install
tar -I 'zstd -T0 -10' -cf "$OUT_DIR/kernel-modules-$KREL.tar.zst" \
  -C "$OUT_DIR/modules-root" lib/modules
rm -rf "$OUT_DIR/modules-root"
echo "::endgroup::"
{
  printf 'kernel_release=%s\nkernel_git_revision=%s\narchitecture=%s\ndtb=%s\n' \
    "$KREL" "$(git rev-parse HEAD)" "$KERNEL_ARCH" "$DTB_BASENAME"
} > "$OUT_DIR/kernel-info.txt"
if [ -n "${GITHUB_ENV:-}" ]; then
  printf 'KERNEL_RELEASE=%s\n' "$KREL" >> "$GITHUB_ENV"
fi
echo "Kernel release: $KREL"
