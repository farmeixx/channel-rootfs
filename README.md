# Moto G7 Play (channel) — mainline kernel

This `main` branch builds **only the mainline kernel** for Motorola Moto G7 Play (`channel`).

## GitHub Actions

- **Build mainline kernel** (`mainline.yml`): manually build the kernel on **main** and publish a reusable, validated checkpoint with the matching `boot.img`, DTB and modules.
- **Build Alpine / Debian / Ubuntu rootfs**: select the matching `alpine`, `debian` or `ubuntu` branch in the workflow's **Run workflow** dropdown. Their YAMLs here are only GitHub UI entry points. A rootfs workflow started on `main` **stops with a branch-selection error** and never compiles a rootfs.
- Rootfs branches use their own shell scripts and **download an already successful, unexpired `mainline.yml` checkpoint from `main`**. If `kernel_run_id` is given, that exact kernel run is used; otherwise the latest usable kernel run is selected. If unavailable, the rootfs run fails. No `workflow_dispatch` of kernel from a rootfs build.

> GitHub requires workflow YAML on the default branch for the manual **Run workflow** button. These three small registration YAMLs are kept here for this reason; the distro build scripts, firmware and overlays live only on their respective branches.

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