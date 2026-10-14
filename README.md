# Channel Rootfs Builder

ARM64 kernel and rootfs builds for the Motorola Moto G7 Play (`channel`).

## Workflows

**Build mainline kernel** produces `boot-channel.img`, the Channel DTB and matching modules.

**Build Debian rootfs**, **Build Ubuntu rootfs** and **Build Alpine rootfs** produce independent filesystem images. Each workflow builds from its matching distribution branch and may reuse the kernel artifact.

Use the workflow you need from **Actions**.

## Filesystems

Each distribution publishes its own compressed ext4 image: `debian-channel-rootfs.ext4.zst`, `ubuntu-channel-rootfs.ext4.zst` or `alpine-channel-rootfs.ext4.zst`.

The kernel boots directly from the configured root partition. Keep the kernel modules paired with that build.

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

If `resize2fs` is unavailable, install `e2fsprogs` on Debian/Ubuntu or `e2fsprogs-extra` on Alpine.

Use the **verified root partition** in this command:

```sh
resize2fs /dev/ROOT_PARTITION
df -h /
```

This expands ext4 to the available size of its partition. Never guess the device path.

## Rootfs details

| Distribution | Artifact | Image | Label |
| --- | --- | --- | --- |
| Debian | `channel-debian-rootfs` | `debian-channel-rootfs.ext4.zst` | `debian` |
| Ubuntu | `channel-ubuntu-rootfs` | `ubuntu-channel-rootfs.ext4.zst` | `ubuntu` |
| Alpine | `channel-alpine-rootfs` | `alpine-channel-rootfs.ext4.zst` | `alpine` |

- Format: ext4 (raw, zstd-compressed)
- Ext4 UUID: `89530000-6320-4000-8000-000000000001`
