#!/bin/sh
# Read-only battery/PMI632 diagnostics for Motorola channel (SDM632).
# No register writes, module loading, charger configuration or reboot.
set -u

printf '\n===== SYSTEM =====\n'
uname -r
if [ -r /sys/firmware/devicetree/base/model ]; then
    tr '\000' '\n' < /sys/firmware/devicetree/base/model
fi

printf '\n===== POWER SUPPLIES =====\n'
found=0
for dev in /sys/class/power_supply/*; do
    [ -d "$dev" ] || continue
    found=1
    printf '\n[%s]\n' "${dev##*/}"
    if [ -r "$dev/uevent" ]; then
        grep -E '^POWER_SUPPLY_(TYPE|STATUS|CAPACITY|PRESENT|HEALTH|ONLINE|VOLTAGE_NOW|CURRENT_NOW|TEMP|CHARGE_NOW|CHARGE_FULL)=' "$dev/uevent" || true
    fi
done
[ "$found" -eq 1 ] || echo 'No power_supply entries'

printf '\n===== PMI632 DEVICE TREE =====\n'
base=/sys/firmware/devicetree/base/soc@0/spmi@200f000/pmic@2
if [ -d "$base" ]; then
    for node in "$base"/*; do
        [ -d "$node" ] || continue
        case "${node##*/}" in
            *charger*|*fuel*|*gauge*|*qg*|*bms*|*typec*|*adc*)
                printf '%s' "${node##*/}"
                if [ -r "$node/status" ]; then
                    printf ' (status: '
                    tr -d '\000' < "$node/status"
                    printf ')'
                fi
                printf '\n'
                if [ -r "$node/compatible" ]; then
                    tr '\000' '\n' < "$node/compatible" | sed 's/^/  compatible: /'
                fi
                ;;
        esac
    done
    adc="$base/adc@3100"
    if [ -d "$adc" ]; then
        printf '\nADC channel labels:\n'
        for ch in "$adc"/channel@*; do
            [ -d "$ch" ] || continue
            printf '  %s' "${ch##*/}"
            if [ -r "$ch/label" ]; then
                printf ': '
                tr -d '\000' < "$ch/label"
            fi
            printf '\n'
        done
    fi
else
    echo 'PMI632 primary SPMI node not found at expected path'
fi

printf '\n===== IIO READINGS (unconverted; units depend on attribute) =====\n'
found=0
for dev in /sys/bus/iio/devices/iio:device*; do
    [ -d "$dev" ] || continue
    name=unknown
    [ ! -r "$dev/name" ] || name=$(cat "$dev/name")
    case "$name" in
        *adc*|*ADC*|*vadc*|*VADC*|*pmic*|*PMIC*|*spmi*|*SPMI*) ;;
        *) continue ;;
    esac
    found=1
    printf '[%s: %s]\n' "${dev##*/}" "$name"
    printed=0
    for f in "$dev"/in_*_input "$dev"/in_*_raw; do
        [ -r "$f" ] || continue
        case "${f##*/}" in
            *vbat*|*VBAT*|*bat_*|*BAT_*|*vph*|*VPH*|*usb*|*USB*|*temp*|*TEMP*) ;;
            *) continue ;;
        esac
        printed=1
        value=$(cat "$f" 2>/dev/null) || value='read failed'
        printf '  %s=%s\n' "${f##*/}" "$value"
    done
    [ "$printed" -eq 1 ] || echo '  No matching exposed readings'
done
[ "$found" -eq 1 ] || echo 'No matching IIO ADC devices'

printf '\n===== KERNEL DRIVER CONFIG =====\n'
config=''
if [ -r "/boot/config-$(uname -r)" ]; then
    config="/boot/config-$(uname -r)"
elif [ -r /tmp/channel-kconfig ]; then
    config=/tmp/channel-kconfig
fi
pattern='^(CONFIG_(CHARGER_QCOM_SMB2|GENERIC_ADC_BATTERY|BATTERY_QCOM_BATTMGR|IIO_QCOM_SPMI_VADC5|POWER_SUPPLY)=|# CONFIG_(CHARGER_QCOM_SMB2|GENERIC_ADC_BATTERY|BATTERY_QCOM_BATTMGR|IIO_QCOM_SPMI_VADC5|POWER_SUPPLY) is not set)'
if [ -n "$config" ]; then
    grep -E "$pattern" "$config" || true
elif [ -r /proc/config.gz ] && command -v zcat >/dev/null 2>&1; then
    zcat /proc/config.gz | grep -E "$pattern" || true
else
    echo 'Kernel configuration not available'
fi

printf '\n===== BOOT MESSAGES =====\n'
dmesg 2>/dev/null | grep -Ei 'pmi632|battery|charger|fuel.gauge|qcom.smb|smb5|vbat|spmi-adc' | tail -n 25 || true
