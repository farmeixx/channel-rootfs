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

## Experimental files retained (currently disabled)

The repository retains a read-only VBAT experiment:

- `conf/battery-adc.config` requests `CONFIG_GENERIC_ADC_BATTERY=y` and its
  prerequisites.
- `sh/battery-adc.sh` adds `adc-battery` and `simple-battery` references
  **only to the copied output DTB**, never the source DTS or live hardware.
- It does not bind or access the QG (0x4800), SDAM (0xb100), SMB5 charger,
  IRQs, thermistors, or control registers.

The experiment is disabled in the active `conf/mainline.conf`: `KERNEL_CONFIG_2`
and `KERNEL_DTB_POSTPROCESS` are empty, and `GENERIC_ADC_BATTERY` is not
required. Normal builds therefore do not merge the battery fragment or modify
the DTB.

## Current configuration

The active main kernel uses the upstream **msm8953.config** fragment plus the
explicit CPR4PD/APCS options. We confirmed a real artifact mismatch: the
checkpoint metadata and module directory said `7.3.0-rc7-g1014de5eac08`, while
the compiled Image and module `vermagic` said `7.3.0-rc7-Sanders-Revived+`.
We have **not** established why Kbuild emitted different release strings on
that run, so this is not attributed to the ADC option or file reorganization.

The builder now pins one release for kernel and module compilation, checks the
actual version embedded in `Image.gz`, and verifies every module's `vermagic`.
Checkpoint validation repeats the image/module checks, and rootfs builds reject
mismatched checkpoints before installing modules. The battery experiment stays
disabled until a matched baseline kernel/rootfs pair has been validated by a
fresh build and boot test.

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
