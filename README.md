# Channel rootfs — unified ZIP, shell-driven builds

**Device:** Motorola Moto G7 Play (`channel`), ARM64. This ZIP contains the existing
`mainline/`, `alpine/`, `debian/` and `ubuntu/` builders and their original target
rootfs overlays (NetworkManager, SSH, USB gadget, DHCP and service startup).

No `git clone` is needed to obtain this builder: extract this ZIP. `git` is
installed by `mainline/run.sh` only because the **kernel source** is fetched
from the GitLab repository. All builder scripts are included in the ZIP.


## Mandatory Channel Wi-Fi firmware (no runtime Android mounts)

Before generating **any** rootfs, supply the original WCNSS files from your
own Channel into `firmware/channel/` and run:

```sh
bash scripts/firmware/channel.sh check
```

The build **fails early** when firmware is missing. It installs `wcnss.mdt`,
all required `wcnss.bXX`, and the original NV into the two paths required by
the Linux drivers. **See [FIRMWARE.md](FIRMWARE.md)** for exact sources and
the `scp` commands to copy from your currently working Channel. Firmware
is intentionally **not** included in the ZIP or the public repository.
GitHub Actions rootfs builds likewise need a privately provisioned firmware
directory, or they fail by design.

## Build locally (Ubuntu 24.04 x86_64 recommended)

Requires Linux, `sudo` privileges, internet access, sufficient free disk space
(for kernel source/build and multi-gigabyte rootfs images), and the `apt-get`
package manager. The scripts install their host build dependencies automatically.
The actual kernel and rootfs builds are **not** tested in this ZIP's creation.

```sh
unzip channel-rootfs-full-sh.zip
cd channel-rootfs-full-sh
bash mainline/run.sh
bash alpine/run.sh
bash debian/run.sh
bash ubuntu/run.sh
```

Each rootfs command is independent. Build only the distributions you want. No
rootfs script compiles a kernel. If `out/kernel/checkpoint` is missing/invalid,
it fails instead of installing packages or silently building a replacement.

`mainline/run.sh` compiles from
`https://gitlab.com/vanadium-oss/motorola-msm8953/mainline/linux.git`
(branch `msm8953/latest`) with the existing `mainline/build.sh`, installs its
modules, and creates a boot image using pinned AOSP `mkbootimg`.

### Results

```text
out/
├── kernel/
│   ├── checkpoint/            # Image.gz, DTB, modules, config, release, hashes, boot-channel.img
│   └── images/                # boot.img, boot-channel.img
└── rootfs/
    ├── alpine/                # alpine-channel-rootfs.ext4.zst, rootfs.ext4, boot.img, metadata
    ├── debian/                # debian-channel-rootfs.ext4.zst, rootfs.ext4, boot.img, metadata
    └── ubuntu/                # ubuntu-channel-rootfs.ext4.zst, rootfs.ext4, boot.img, metadata
```

The rootfs `boot.img` is copied directly from the *same* validated checkpoint.
This preserves the original boot cmdline and kernel/module pairing. Rootfs
images retain their existing overlay, package selection and startup services.

You can reuse a checkpoint from a different directory using:

```sh
KERNEL_CHECKPOINT_DIR=/path/to/checkpoint bash alpine/run.sh
```

The checkpoint must contain `SHA256SUMS`, `kernel-release.txt`, `Image.gz`,
`boot-channel.img`, the Channel DTB, matching `kernel-modules-*.tar.zst`,
`kernel.config` and `System.map`. The legacy Action checksum paths (`out/`)
are supported.

## CI (optional)

The four small `.github/workflows/*.yml` files call these same shell scripts.
They are present for later publication of the **unified** repository; extracting
this ZIP does **not** enable any Actions workflows until someone intentionally
pushes the unified files into a GitHub repository.

- **Build mainline kernel:** manually builds and publishes the checkpoint.
- **Build Alpine/Debian/Ubuntu:** downloads the newest live checkpoint from
  `mainline.yml`, or the explicit `kernel_run_id` supplied on dispatch, then
  runs the distribution's shell entry point. An unavailable/expired checkpoint
  is a hard failure; there is no temporary kernel build.
- The GitHub CLI is used only by the CI download helper. Local builds do not
  need GitHub authentication or previous CI runs.

## Target network / SSH

Each rootfs keeps NetworkManager (`nmcli`) for Wi-Fi, USB gadget + DHCP and
SSH bound to the USB device address `172.16.42.1`. For SSH after boot:

```sh
ssh root@172.16.42.1
```

This intentionally reflects the existing project's USB-only SSH policy. See
individual `*/build.sh` and `*/rootfs/` for the precise configuration.

## Ubuntu 22.04 / WSL2 QEMU binfmt support

On some WSL installations, `qemu-user-static` is installed but the kernel
interpreter is not registered. `scripts/host-deps.sh` now registers just the
AArch64 ELF interpreter in `binfmt_misc` using the installed static QEMU,
without restarting `systemd-binfmt` or disturbing WSL's Windows-binary handler.
If the WSL kernel prevents mounting/writing `binfmt_misc`, the script stops
with a diagnostic instead of proceeding into a broken arm64 chroot.

If a previous run successfully created `out/kernel/checkpoint`, keep it and
rerun only `bash alpine/run.sh` after applying the patched `host-deps.sh`.

## Notes

- The build host is expected to be Linux x86_64 with Ubuntu/Debian `apt-get`,
  not Windows CMD or a bare Android shell. Use a compatible Linux machine/VM/CI.
- No commits or GitHub pushes were made while preparing this ZIP.
- The existing `mainline/publish-rootfs-images.sh` is retained as reference;
  `scripts/rootfs/run.sh` now handles copying boot.img and extracting ext4.
