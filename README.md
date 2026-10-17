# Moto G7 Play (channel) — mainline kernel

The `main` branch contains the kernel builder and GitHub Actions workflow entry points for Motorola Moto G7 Play (`channel`). **All three rootfs builders now live together on [`rootfs`](https://github.com/farmeixx/channel-rootfs/tree/rootfs)**, with independent Alpine/Debian/Ubuntu directories and shared firmware/tools.

## GitHub Actions

- **Build mainline kernel** (`mainline.yml`): run on **main** to build and publish the validated kernel checkpoint (`boot.img`, DTB, modules, hashes). ARM64 GCC builds use a persistent GitHub Actions `ccache` (maximum 2 GiB).
- **Build alpine rootfs** (`alpine.yml`): on **main**, checks out `rootfs` and invokes `bash scripts/ci/build-rootfs.sh alpine`.
- **Build debian rootfs** (`debian.yml`): on **main**, checks out `rootfs` and invokes `bash scripts/ci/build-rootfs.sh debian`.
- **Build ubuntu rootfs** (`ubuntu.yml`): on **main**, checks out `rootfs` and invokes `bash scripts/ci/build-rootfs.sh ubuntu`.

Every rootfs builder **reuses an already successful, unexpired** `mainline.yml` checkpoint from **main**. The newest usable kernel checkpoint is selected automatically. There is no Run ID input, and a rootfs workflow **never dispatches or compiles the kernel**. If no checkpoint is available, the rootfs job fails.

The YAMLs on `main` are entry points only: they choose the `rootfs` branch, call the appropriate shell script, and upload the same per-distro artifacts as before. GitHub requires workflows on the default branch for reliable manual dispatch.

## Build kernel locally (Linux x86_64)

```sh
bash mainline/run.sh
```

This installs/checks host dependencies, fetches the selected kernel source, builds the Channel DTB and modules, and produces:

```text
out/kernel/checkpoint/   # validated Image.gz, DTB, modules, boot-channel.img, SHA256SUMS
out/kernel/images/boot.img
```

For rootfs instructions, see the [rootfs branch README](https://github.com/farmeixx/channel-rootfs/blob/rootfs/README.md). Its distro build scripts and bundled firmware are separate from the kernel builder.

## Branches

- `main`: dedicated mainline kernel build, ccache and Actions entry YAMLs.
- [`rootfs`](https://github.com/farmeixx/channel-rootfs/tree/rootfs): Alpine, Debian, Ubuntu, common rootfs scripts and Channel firmware.
- [`help`](https://github.com/farmeixx/channel-rootfs/tree/help): short setup and usage commands (SSH, Wi-Fi, date, `resize2fs`).

The old `alpine`, `debian`, and `ubuntu` branches are retained temporarily as rollback references, but **new rootfs work belongs on `rootfs`**.
