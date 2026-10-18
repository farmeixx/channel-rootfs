# Firmware source and installation

Device-specific configuration: [firmware/channel/firmware.conf](firmware/channel/firmware.conf).

The shared [scripts/firmware/install.sh](scripts/firmware/install.sh) reads
`FIRMWARE_URL`, optional `FIRMWARE_REF`, directory mappings and aliases.
It clones the complete `channel-firmware` repository, checks its SHA256SUMS
when present, copies **every firmware file** in the configured directories,
then installs two Channel NV aliases for the WCN36xx driver and DT.
This installs WCNSS, ADSP, modem, Venus, GPU and touchscreen firmware;
firmware binaries are copied, **not compiled**.

The checked-in old WCNSS fallback/segmented b06 package was removed.
The default source is the full Channel firmware repository vendored at
`firmware/channel/source/` when available. If not yet imported, the installer
clones the original GitLab repository. No firmware sets are mixed.
The user-tested Channel RAR contains the same layout and can also be used
offline with `FIRMWARE_SOURCE_ARCHIVE=/path/to/channel-firmware.rar` (requires
`bsdtar`) or its extracted contents with `FIRMWARE_SOURCE_DIR=/path/to/extracted`.
The optional archive SHA256 is defined in firmware.conf. No large binary payload
is stored in this rootfs branch.

Example:
```sh
bash scripts/firmware/install.sh check
bash scripts/firmware/install.sh install /path/to/staged/rootfs
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
