# Moto G7 Play (channel) — unified rootfs builders

This `rootfs` branch contains **Alpine, Debian and Ubuntu** for Channel. The three distro builders have independent directories; common tooling and the Channel firmware are shared once.

## Layout

- `alpine/build.sh`, `alpine/run.sh`, `alpine/rootfs/`: Alpine builder and overlays.
- `debian/build.sh`, `debian/run.sh`, `debian/rootfs/`: Debian builder and overlays.
- `ubuntu/build.sh`, `ubuntu/run.sh`, `ubuntu/rootfs/`: Ubuntu builder and overlays.
- `scripts/ci/build-rootfs.sh`: selects one distribution, then reuses an existing kernel checkpoint.
- `scripts/ci/fetch-kernel.sh`: downloads the newest successful unexpired kernel checkpoint from the **main** branch. Never dispatches or rebuilds a kernel.
- `scripts/rootfs/run.sh`, `scripts/host-deps.sh`, `scripts/kernel/validate.sh`: shared rootfs build support.
- `scripts/firmware/channel.sh`: a shared installer that prefers a SHA-256-verified GitLab WCNSS set and safely falls back to bundled firmware until the upstream WCNSS upload is completed.

## GitHub Actions

Select **Build alpine rootfs**, **Build debian rootfs**, or **Build ubuntu rootfs** from the repository Actions tab, using branch **main**. Their lightweight YAML entry points live on `main`, check out this `rootfs` branch, and call:

```bash
bash scripts/ci/build-rootfs.sh alpine  # or debian / ubuntu
```

Rootfs workflows reuse the latest **successful, unexpired** kernel checkpoint from `mainline.yml` on `main`. If none exists, they fail rather than starting a kernel build. The kernel builder and ccache remain on `main`.

## Generic USB management service names

The rootfs USB/RNDIS management components now use distro-neutral **service
and script names**. This is a naming-only change for the Channel test:

- All distros: `/usr/local/sbin/usb-gadget` (formerly `channel-usb-gadget`).
- Alpine OpenRC: `usb-gadget`, `usb-sshd`; packaged `dnsmasq` reads
  `/etc/dnsmasq-usb.conf` and depends on `usb-gadget`.
- Debian/Ubuntu systemd: `usb-gadget.service` and `usb-dhcp.service`.
  `ssh.service` requires `usb-gadget.service`, preserving startup order.
- SSH configuration: `/etc/ssh/sshd_config.d/10-usb-ssh.conf`; Debian/Ubuntu
  also install `/etc/systemd/system/ssh.service.d/10-usb.conf`.

**Shared ConfigFS implementation:** instead of three separately maintained gadget
scripts, every distro installs the same
`scripts/usb/usb-gadget` into `/usr/local/sbin/usb-gadget` and the same
`scripts/usb/channel.conf` into `/etc/usb-gadget.conf`. The script reads
device identity, USB MACs, fixed RNDIS interface and management address from
this root-owned file. Alpine / Debian / Ubuntu product strings are derived
from `/etc/os-release`, preserving the original USB descriptors.

A second start of an already-matching active gadget **does not rebind its
UDC or flush the network address**. Conflicting active settings are rejected
without disconnecting SSH. An unbound incomplete gadget is cleaned before
recreation. The runtime resolves the netdev from the RNDIS `ifname` attribute
or its MAC and fails clearly if it is not `usb0`, because DHCP and
NetworkManager intentionally use that fixed name.

**Validation:** tested with a simulated ConfigFS/UDC/netdev for first start,
second start, conflicting active settings and missing UDC. This does not
replace a real Channel boot + USB/RNDIS/SSH hardware test.

The ConfigFS gadget directory is now `/sys/kernel/config/usb_gadget/usb-gadget`.
**Channel-specific USB descriptors, serial prefix, VID/PID, MAC addresses,
RNDIS function, interface `usb0`, DHCP scope `172.16.42.2–20`, and
`sshd` bind address `172.16.42.1` are unchanged.** There is no new USB
protocol or driver. Firmware, kernel and main-branch Actions are unaffected.

After testing on Channel:

```sh
ip -br addr show usb0
# Alpine:
rc-service usb-gadget status
rc-service usb-sshd status
# Debian/Ubuntu:
systemctl status usb-gadget.service usb-dhcp.service ssh.service
```

From the USB host, connect via `ssh root@172.16.42.1`. A valid RNDIS-capable
kernel/UDC is still required; file/service checks do not prove hardware boot.

## Alpine 512 MiB ext4 image

The Alpine builder now targets a **fixed 512 MiB uncompressed ext4 image**
(`536870912` bytes). Zstandard download size will vary. Before writing the
image, it drops only the disposable APK cache; installed Wi-Fi firmware, kernel
modules, RNDIS, SSH and NetworkManager are unchanged. It provisions 16,384
ext4 inodes and an 8 MiB journal (journaling remains enabled).

After populating ext4, it runs `e2fsck`, inspects actual filesystem free
blocks via `tune2fs`, and **fails the build if less than 32 MiB remain**.
The metadata reports `image_size_mib`, `image_free_mib`,
`image_min_free_mib`, and `staged_rootfs_mib`; final CI orchestration checks
that the expanded Alpine `rootfs.ext4` is exactly 512 MiB. A size reduction
cannot itself demonstrate runtime stability: the Channel must be rebooted and
USB SSH / Wi-Fi retested with the newly built image. If this build fails the
free-space guard, reduce installed footprint rather than bypassing it.

Debian is **not resized**: the current builder uses
`max(1536 MiB, staged_rootfs_MiB + 700 MiB)`. It has no measured minimum
from a successful Debian CI build yet. Measure staged tree size and actual
ext4 free space before considering a smaller target.

## Local builds

On an x86_64 Linux host, make the `main` kernel checkpoint available at `out/kernel/checkpoint/` and run one of:

```bash
bash alpine/run.sh
bash debian/run.sh
bash ubuntu/run.sh
```

Each distribution has its own `out/rootfs/DISTRO/` output directory. `boot.img` is copied from the same kernel checkpoint; it is not rebuilt by the rootfs process.

## Previous branches

The original `alpine`, `debian`, and `ubuntu` branches are retained temporarily for rollback. Use `rootfs` for subsequent rootfs changes and `main` for kernel / GitHub Actions entry points.

See [FIRMWARE.md](FIRMWARE.md) for firmware provenance and checks.
