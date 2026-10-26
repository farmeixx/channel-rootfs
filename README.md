# Channel mainline kernel builder

The **main** branch contains the kernel builder and the GitHub Actions entry
points. Device-specific settings live in [`conf/mainline.conf`](conf/mainline.conf)
(and `conf/device.conf`, `conf/build.conf`, `conf/kernel.conf`). No firmware or
rootfs overlay lives on this branch. Zero validation layers: failures surface
in the run log.

## Layout

```text
conf/
  device.conf            # DEVICE identity
  build.conf             # JOBS, ccache size/compress, modules archive base
  kernel.conf            # KERNEL_LOCALVERSION release label (byte-exact)
  mainline.conf          # source, branch, fragments, DTB, boot.img, cmdline
sh/
  run.sh                 # orchestrate checkout/build/checkpoint publication
  build.sh               # compile kernel, DTB and modules (conf-driven)
  bootimg.sh             # create the Android boot image
  deps.sh                # build host dependencies and ccache
docs/
  mainline.md            # configuration details
.github/workflows/
  mainline.yml           # manual kernel build
  alpine.yml             # dispatch rootfs build from rootfs branch
  debian.yml
  ubuntu.yml
```

## Build

```sh
bash sh/run.sh
```

The kernel build publishes the reusable checkpoint in
`cache/mainline/checkpoint/` (kernel, modules archive, DTB, boot image,
config), a dated copy under `build/mainline/`, and the module archive under
`cache/mainline/modules/`. ccache is persistent between builds (GitHub runners
cache `cache/mainline/ccache`). To update the kernel source manually:
`git -C sources/linux pull --ff-only`.

Rootfs workflows **do not compile or dispatch a kernel**. They check out the
[`rootfs` branch](https://github.com/farmeixx/channel-rootfs/tree/rootfs) and
reuse the latest successful, unexpired kernel checkpoint from `mainline.yml`.
All workflows are manually dispatched; firmware is not stored here — rootfs
builds clone the upstream `channel-firmware` repository on GitLab at build time.

See [configuration and porting notes](docs/mainline.md) and
[`rootfs` README](https://github.com/farmeixx/channel-rootfs/blob/rootfs/README.md).
