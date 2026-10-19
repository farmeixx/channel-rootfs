# PMI632 battery - experiment paused during boot regression

**PAUSED ON MAIN DURING BOOT TRIAGE:** the battery fragment and DTB postprocessing are disabled. The experiment is **NOT** a full PMI632 QG fuel-gauge or SMB5 charger port.
It is a safe first milestone: expose a real ADC measurement of VBAT
through Linux's existing `generic-adc-battery` power_supply driver.

## Hardware evidence from booted Channel (7.3.0-rc7)

- SPMI PMIC: `qcom,pmi632` at `/soc@0/spmi@200f000/pmic@2`
- ADC: `/soc@0/spmi@200f000/pmic@2/adc@3100`
- IIO channel `in_voltage_vbat_sns_input`: 3690699 microvolts
- `in_voltage_vph_pwr_input`: 3767580 microvolts
- `in_voltage_usb_in_v_div_16_input`: 5078192 microvolts
- No QG node at 0x4800, no battery power supply exposed in stock mainline.

The standard kernel `pmi632.dtsi` uses `ADC5_VBAT_SNS = 0x84` and a
single IIO channel cell. This test checks that address/format in the built DTB.

## What this branch changes

- `conf/battery-adc.config` requests `CONFIG_GENERIC_ADC_BATTERY=y`.
- `conf/mainline.conf` requests that fragment and `sh/battery-adc.sh` as an
  optional post-processing hook, plus validates the Kconfig result.
- The postprocessor adds `adc-battery` and `simple-battery` references
  **only to the copied output DTB**, not the source DTS or live hardware.
  The boot image then uses the resulting DTB.
- It does not bind or access the QG (0x4800), SDAM (0xb100), SMB5 charger,
  IRQs, thermistors, or control registers.
- Only the `main` kernel build gains this optional experimental monitor;
  existing CPUFreq, WCNSS firmware, USB settings and the `rootfs` branch
  are otherwise unchanged.

## Current configuration

The main kernel uses the upstream **msm8953.config** fragment again, plus explicitly requested CPR4PD/APCS drivers. The upstream fragment's `CONFIG_LOCALVERSION=-Sanders-Revived` is normal; the real regression was that a refactor stopped passing `KERNELRELEASE` to the compilation step while still passing it to `modules_install`. The kernel builder now passes the same release to both and checks the built `UTS_RELEASE` and module ELF `vermagic`. The battery monitor remains disabled until a matched kernel/rootfs boot is validated.

## How to build

Open GitHub Actions -> **Build mainline kernel** -> **Run workflow**,
choose branch `main`, then start. Rootfs jobs reuse the latest successful,
unexpired kernel checkpoint published by this workflow on `main`.

The historical `battery-pmi632-test` branch is not required by any workflow.

Alternatively on an x86_64 Ubuntu/Debian build host:

```sh
bash sh/run.sh
```

## Verify after booting the experimental boot.img

```sh
uname -r
ls -l /sys/class/power_supply
for p in /sys/class/power_supply/*; do
  [ -r "$p/type" ] || continue
  echo "${p##*/}: $(cat "$p/type")"
  [ ! -r "$p/voltage_now" ] || cat "$p/voltage_now"
done
cat /sys/bus/iio/devices/iio:device0/in_voltage_vbat_sns_input
dmesg | grep -Ei 'adc-battery|battery-monitor|generic-adc-battery|defer|failed' | tail -n 50
```

Expected **only when the experiment is explicitly re-enabled** and the driver successfully binds: `battery-monitor` as a
`Battery` power supply, plus a measured `voltage_now` similar to the
IIO `vbat_sns` reading.

**Do not rely on `status`**: the generic driver defaults to Discharging
without a real charger provider. No `capacity` percentage, battery current,
battery temperature, or verified charge-state is supplied by this experiment.

## Next stage: actual QG support

To implement a true State of Charge, inspect the stock Motorola battery
profile/thermistor properties, the Qualcomm PMI632 QG peripheral at 0x4800,
SDAM at 0xb100, and upstream Android `qpnp-qg` implementation. This will
require a real mainline driver or an appropriate validated alternative.
Do not transplant Android QG/SMB5 drivers and enable charging registers
without reviewing their writes, IRQs and battery thermal protections.
