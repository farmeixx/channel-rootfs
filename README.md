# Alpine Rootfs — Channel

Alpine Linux ARM64 with OpenRC for the Motorola Moto G7 Play.

## Build

The `alpine` branch contains `alpine/build.sh` and `.github/workflows/alpine.yml`.

The workflow installs matching mainline kernel modules. Artifact: `channel-alpine-rootfs`.

## Network

Connect over the USB gadget:

```sh
ssh root@172.16.42.1
```

For Wi-Fi, use NetworkManager on the device:

```sh
nmcli device wifi list
nmcli --ask device wifi connect "SSID" ifname wlan0
```

## Time

If the clock is incorrect, set the actual UTC time manually:

```sh
date -u -s "YYYY-MM-DD HH:MM:SS"
date
```

## Expand the root filesystem

After boot, run as root and identify the ext4 partition mounted at `/`:

```sh
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS
grep ' / ' /proc/mounts
command -v resize2fs
```

For Alpine, install it if missing:

```sh
apk add e2fsprogs-extra
```

Use the **verified root partition** in this command:

```sh
resize2fs /dev/ROOT_PARTITION
df -h /
```

This expands ext4 to the available size of its partition. Never guess the device path.

## Rootfs details

- Artifact: `channel-alpine-rootfs`
- Image: `alpine-channel-rootfs.ext4.zst`
- Format: ext4 (raw, zstd-compressed)
- Label: `alpine`
- UUID: `89530000-6320-4000-8000-000000000001`
