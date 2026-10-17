# GitLab-first firmware selection

The builder now prefers the upstream [Channel firmware repository](https://gitlab.com/vanadium-oss/motorola-msm8953/mainline/channel-firmware), but the complete WCNSS files are still listed as pending there. To avoid breaking working Wi-Fi, the SH keeps a **verified bundled fallback**.

- `CHANNEL_FIRMWARE_SOURCE=auto` (default): use GitLab only if its WCNSS segments and base NV pass the existing SHA-256 checks; otherwise use bundled firmware.
- `CHANNEL_FIRMWARE_SOURCE=gitlab`: strictly require GitLab, and fail if WCNSS is missing or differs.
- `CHANNEL_FIRMWARE_SOURCE=bundled`: use verified offline bundle without remote access.
- Optional `CHANNEL_FIRMWARE_URL` and `CHANNEL_FIRMWARE_REF` select the repository and revision.

Put WCNSS parts under `wlan/wcnss/` in the GitLab repository and use the existing `wlan/WCNSS_qcom_wlan_nv.bin` base NV. Existing hashes must match `firmware/channel/SHA256SUMS`, including reconstructed `wcnss.b06`. The regional NV, GPU and touchscreen firmware are not substituted for the working WCNSS set. The old bundled firmware can be deleted **only after** a successful CI run using `CHANNEL_FIRMWARE_SOURCE=gitlab`.

# Motorola Moto G7 Play (`channel`) WCNSS firmware

Firmware used in the Wi-Fi test on `channel` (mainline kernel 7.3.0-rc7).
`wcnss.mdt`, the nine available `wcnss.bXX` segments and
`WCNSS_qcom_wlan_nv.bin` are **included in this project**. No manual extraction,
firmware download, GitHub secret, or runtime Android-partition mount is required.

The Wi-Fi device registered through `wcn36xx`; the Channel connected to a WPA2
access point and successfully pinged 1.1.1.1 (3/3 packets). This does not prove
long-term stability, and firmware compatibility remains specific to Channel / the
relevant hardware variant.

The source firmware image files originate from the device's stock `modem_a`
partition; the NV file came from `vendor_a/etc/wifi/WCNSS_qcom_wlan_nv.bin`.
Both copies of NV in the original transfer archive are byte-identical. The
manifest in `firmware/channel/SHA256SUMS` verifies the bundled file contents.
The largest firmware segment (`wcnss.b06`) is stored as three compressed parts
for repository transport; `scripts/firmware/channel.sh` restores the original
3,290,256 bytes automatically **at build time** and validates its SHA-256.
No user action is required.

The rootfs builder copies files to:

```text
/lib/firmware/wcnss.mdt
/lib/firmware/wcnss.b00, .b01, .b02, .b04, .b06, .b09, .b10, .b11, .b12
/lib/firmware/wlan/prima/WCNSS_qcom_wlan_nv.bin
/lib/firmware/qcom/msm8953/motorola/channel/WCNSS_qcom_wlan_nv.bin
```

The device tree / driver identifies the expected NV firmware **path**. Firmware
bytes do not come from the DTB. Firmware images may be shared between compatible
units; *unit-specific* calibration and identifiers may live separately in other
partitions. Do not copy `modemst1`, `modemst2`, or device calibration partitions.

The firmware may be proprietary and subject to vendor licensing; review those
terms before redistributing publicly or reusing on other hardware.
