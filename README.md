# Moto G7 Play (channel) — mainline kernel

This `main` branch holds **only the mainline kernel builder and GitHub Actions entry workflows** for Motorola Moto G7 Play (`channel`). The distro sources live on their separate branches.

## GitHub Actions

- **Build mainline kernel** (`mainline.yml`): manually build the kernel on **main** and publish a reusable, validated checkpoint with the matching `boot.img`, DTB and modules.
- **Build Alpine / Debian / Ubuntu rootfs**: run the corresponding workflow directly on **`main`**. Its YAML checks out the relevant `alpine`, `debian` or `ubuntu` branch and runs `bash scripts/ci/build-rootfs.sh DISTRO`, without duplicating the build logic in YAML. Alternatively, the workflow in each distro branch still works when selected.
- Rootfs branches use their own shell scripts and **download an already successful, unexpired `mainline.yml` checkpoint from `main`**. The newest successful kernel run with an unexpired checkpoint artifact is selected automatically. No run ID is needed or accepted. If no usable checkpoint is available, the rootfs run fails. No `workflow_dispatch` of kernel from a rootfs build.

> GitHub requires workflow YAML on the default branch for manual **Run workflow**. The three YAMLs here are functional entry points: they fetch the corresponding distro branch, whose scripts, firmware and overlays remain separate from `main`.

## Build kernel locally (Linux x86_64)

```sh
bash mainline/run.sh
```

This checks/install host dependencies, fetches the selected kernel source, builds the Channel DTB and modules, and produces:

```text
out/kernel/checkpoint/   # checked kernel Image.gz, DTB, modules, boot-channel.img and SHA256SUMS
out/kernel/images/boot.img
```

No rootfs or Android firmware files are required to build the kernel. This build has not been rerun as part of this cleanup.

## Other branches

- [`alpine`](https://github.com/farmeixx/channel-rootfs/tree/alpine)
- [`debian`](https://github.com/farmeixx/channel-rootfs/tree/debian)
- [`ubuntu`](https://github.com/farmeixx/channel-rootfs/tree/ubuntu)
- [`help`](https://github.com/farmeixx/channel-rootfs/tree/help) — short usage commands (SSH, Wi-Fi, date, `resize2fs`).