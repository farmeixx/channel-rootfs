# Channel Wi-Fi firmware: mandatory local input

**Verified on Moto G7 Play (`channel`) with Linux 7.3.0-rc7:** the WCNSS remoteproc
loaded `wcnss.mdt`, WCNSS control reported 1.5/1.2, `wcn36xx` registered
`wlan0`, NetworkManager connected to Wi-Fi, and an IPv4 internet ping worked.
These are device test results, **not** a promise of success on every build.

The kernel needs WCNSS firmware **before** NetworkManager can see `wlan0`.
The WCNSS control driver on this Channel kernel specifically requests
`qcom/msm8953/motorola/channel/WCNSS_qcom_wlan_nv.bin`.
The `wcn36xx` module also advertises `wlan/prima/WCNSS_qcom_wlan_nv.bin`.
The shell builder copies the same NV file into both locations in the image.

## Provide the firmware from your own device

These files are proprietary, are not bundled into either public ZIP and
**must not be committed to GitHub**. Obtain them from the Channel's original
partitions or from `/lib/firmware/` of the **already fixed, running Channel**.

From your Linux build host, with USB SSH to the Channel at 172.16.42.1,
run **inside the extracted project directory**:

```sh
mkdir -p firmware/channel
scp 'root@172.16.42.1:/lib/firmware/wcnss.mdt' firmware/channel/
scp 'root@172.16.42.1:/lib/firmware/wcnss.b*' firmware/channel/
scp 'root@172.16.42.1:/lib/firmware/qcom/msm8953/motorola/channel/WCNSS_qcom_wlan_nv.bin' firmware/channel/
bash scripts/firmware/channel.sh check
```

If the remote kernel-specific NV copy is absent, use the previously validated
`/lib/firmware/wlan/prima/WCNSS_qcom_wlan_nv.bin` on the device instead.
Do not use random regional NV firmware or overwrite `/persist` or modemst.

**Original source partitions on the tested Channel:**

- `modem_a` (`/dev/mmcblk0p19`): `image/wcnss.mdt`, `image/wcnss.b00`,
  `.b01`, `.b02`, `.b04`, `.b06`, `.b09`, `.b10`, `.b11`, `.b12`.
- `vendor_a` (`/dev/mmcblk0p60`):
  `firmware/wlan/prima/WCNSS_qcom_wlan_nv.bin` and
  `etc/wifi/WCNSS_qcom_wlan_nv.bin`.

If reading directly on the Channel, mounts must be **temporary and read-only**,
then copied to a regular directory. The resulting Alpine/Debian/Ubuntu images
contain regular files in `/lib/firmware`; no Android partitions are mounted
at runtime and no Android `wcnss_service` is installed.

## Build and verify

```sh
bash scripts/firmware/channel.sh check
bash mainline/run.sh      # only if you still need the kernel checkpoint
bash alpine/run.sh        # similarly debian/run.sh or ubuntu/run.sh
```

The rootfs entry point fails **before host package installation**, rootfs
extraction or rebuilding if these firmware files are absent. It reuses the
existing kernel checkpoint. Target rootfs outputs include:

```text
/lib/firmware/wcnss.mdt
/lib/firmware/wcnss.b00 ... b12 (matching original partition files)
/lib/firmware/wlan/prima/WCNSS_qcom_wlan_nv.bin
/lib/firmware/qcom/msm8953/motorola/channel/WCNSS_qcom_wlan_nv.bin
```

For CI, the runner must be provisioned with these same **privately supplied**
files and set `CHANNEL_FIRMWARE_DIR`. Public GitHub runners do not have them;
without provisioning, rootfs builds correctly fail. Do not upload firmware as
public artifacts, repository files, or plaintext Actions logs.

The firmware/ directory is ignored by Git (except its placeholder). The two ZIP
variants share this same firmware policy but differ in host dependency setup.
