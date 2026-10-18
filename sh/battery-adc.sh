#!/usr/bin/env bash
# Experimental read-only Channel voltage monitor.
# Postprocesses ONLY a copied DTB, never the cloned kernel DTS, live SPMI
# registers, charger controls, or the stable kernel checkpoint.
set -euo pipefail
: "${1:?Usage: bash battery-adc.sh KERNEL_DTB}"
DTB="$1"
test -s "$DTB"
for tool in dtc fdtget fdtput; do
  command -v "$tool" >/dev/null || { echo "Missing device-tree-compiler tool: $tool" >&2; exit 1; }
done

ADC='/soc@0/spmi@200f000/pmic@2/adc@3100'
BATT='/battery-channel'
MON='/battery-monitor'
test "$(fdtget -t x "$DTB" "$ADC" '#io-channel-cells')" = 1 || {
  echo "Expected PMI632 ADC with 1 IIO channel cell not present" >&2; exit 1;
}
if fdtget -t s "$DTB" "$BATT" compatible >/dev/null 2>&1 ||
   fdtget -t s "$DTB" "$MON" compatible >/dev/null 2>&1; then
  echo "Battery node already exists; refusing to overwrite" >&2
  exit 1
fi

# Find free phandles instead of guessing a fixed ID that may collide.
max=0
while IFS= read -r hex; do
  [[ "$hex" =~ ^[0-9a-fA-F]+$ ]] || exit 1
  value=$((16#$hex))
  if (( value > max )); then max="$value"; fi
done < <(dtc -I dtb -O dts "$DTB" 2>/dev/null |
  sed -nE 's/^[[:space:]]*(linux,)?phandle = <0x([[:xdigit:]]+)>;.*/\2/p')
if (( max >= 0xfffffffc )); then echo "No free phandle IDs" >&2; exit 1; fi

adc_hex="$(fdtget -t x "$DTB" "$ADC" phandle 2>/dev/null || true)"
if [ -n "$adc_hex" ]; then
  [[ "$adc_hex" =~ ^[0-9a-fA-F]+$ ]] || { echo "Invalid ADC phandle" >&2; exit 1; }
  adc_id=$((16#$adc_hex))
  (( adc_id > 0 && adc_id < 0xffffffff )) || exit 1
  bat_id=$((max + 1))
else
  adc_id=$((max + 1))
  bat_id=$((max + 2))
fi

# Atomic: never leave a broken DTB at the checkpoint path.
temp="$(mktemp "${DTB}.XXXXXX")"
trap 'rm -f "$temp"' EXIT
cp "$DTB" "$temp"
if [ -z "$adc_hex" ]; then
  fdtput -t x "$temp" "$ADC" phandle "$(printf '%x' "$adc_id")"
fi

fdtput -c "$temp" "$BATT"
fdtput -c "$temp" "$MON"
fdtput -t s "$temp" "$BATT" compatible simple-battery
fdtput -t x "$temp" "$BATT" phandle "$(printf '%x' "$bat_id")"
fdtput -t s "$temp" "$MON" compatible adc-battery
# ADC5_VBAT_SNS is 0x84 in dt-bindings/iio/qcom,spmi-vadc.h.
fdtput -t x "$temp" "$MON" io-channels "$(printf '%x' "$adc_id")" 84
fdtput -t s "$temp" "$MON" io-channel-names voltage
fdtput -t x "$temp" "$MON" monitored-battery "$(printf '%x' "$bat_id")"

test "$(fdtget -t s "$temp" "$MON" compatible)" = adc-battery
test "$(fdtget -t x "$temp" "$MON" io-channels)" = "$(printf '%x' "$adc_id") 84"
test "$(fdtget -t x "$temp" "$MON" monitored-battery)" = "$(printf '%x' "$bat_id")"
mv -f "$temp" "$DTB"
echo 'Experimental PMI632 VBAT monitor installed in output DTB (voltage only; no SoC or charging control).'
