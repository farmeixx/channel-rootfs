# Firmware source and installation

Device-specific configuration: [conf/firmware.conf](../conf/firmware.conf).

The shared [sh/firmware.sh](../sh/firmware.sh) reads
`FIRMWARE_URL`, optional `FIRMWARE_REF`, directory mappings and aliases.
It clones the complete `channel-firmware` repository, copies **every firmware
file** in the configured directories, then installs two Channel NV aliases
for the WCN36xx driver and DT. This installs WCNSS, ADSP, modem, Venus, GPU
and touchscreen firmware; firmware binaries are copied, **not compiled**.

The firmware is not stored in this repository: the installer clones the
complete `channel-firmware` repository (`FIRMWARE_URL`) at build time.
For offline builds, `FIRMWARE_SOURCE_DIR=/path/to/extracted` points the
installer at an already available local tree with the same layout.
No large binary payload is stored in this rootfs branch.

Example:
```sh
bash sh/firmware.sh install /path/to/staged/rootfs
```

Firmware mapping for Channel:
- `modem/*` -> `/lib/firmware/*` (including `wcnss.*`, `adsp.*`, `venus.*`)
- `qcom/*` -> `/lib/firmware/qcom/*`
- `touchscreen/*` -> `/lib/firmware/touchscreen/*`
- `wlan/*` -> `/lib/firmware/wlan/*`
- `wlan/WCNSS_qcom_wlan_nv.bin` -> the two additional driver/DT paths
  `wlan/prima/WCNSS_qcom_wlan_nv.bin` and
  `qcom/msm8953/motorola/channel/WCNSS_qcom_wlan_nv.bin`

No firmware is read from live Android partitions. Preserve recovery images
when testing different firmware sets. Proprietary redistribution rights still
apply.
