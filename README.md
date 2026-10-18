# Channel mainline kernel builder

The **main** branch contains the kernel builder and GitHub Actions entry points.
Device-specific settings live in [`conf/mainline.conf`](conf/mainline.conf).
No firmware or rootfs overlay lives on this branch.

## Layout

```text
conf/
  mainline.conf           # source, branch, clone path, two optional configs, DTB, boot.img
sh/
  run.sh                  # orchestrate kernel checkout/build/checkpoint
  build.sh                # compile kernel, DTB and modules
  bootimg.sh              # create Android boot image
  validate.sh             # verify kernel checkpoint
  deps.sh                 # build host dependencies and ccache
docs/
  mainline.md             # configuration details
.github/workflows/
  mainline.yml            # manual kernel build
  alpine.yml             # dispatch rootfs build from rootfs branch
  debian.yml
  ubuntu.yml
```

## Build

```sh
bash sh/run.sh
```

Kernel build writes `out/kernel/checkpoint/` (kernel, modules, DTB, boot image,
config, hashes) and `out/kernel/images/boot.img`. The checkpoint is published
only after validation succeeds; ccache is used on the GitHub runner.

Rootfs workflows **do not compile or dispatch a kernel**. They check out the
[`rootfs` branch](https://github.com/farmeixx/channel-rootfs/tree/rootfs)
and reuse the latest successful, unexpired kernel checkpoint from `mainline.yml`.
All workflows are manually dispatched; the one-off firmware import workflow was
removed once firmware was vendored into `rootfs`.

See [configuration and porting notes](docs/mainline.md) and
[`rootfs` README](https://github.com/farmeixx/channel-rootfs/blob/rootfs/README.md).
