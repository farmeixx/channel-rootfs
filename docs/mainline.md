# Generic mainline kernel builder

Configure **conf/mainline.conf** (plus `conf/device.conf`, `conf/build.conf`
and `conf/kernel.conf`) at the repository root before running:

```bash
bash sh/run.sh
```

The shared scripts do not contain Channel source URLs, kernel branches, config
fragments, DTB paths or boot-image offsets. All are configured in conf. There
are no validation layers: if something is wrong, it fails in the run log.

Important options:
- `KERNEL_URL`, `KERNEL_REF`: source repository and branch (cloned once into
  `sources/linux`; manual update via `git -C sources/linux pull --ff-only`)
- `KERNEL_BASE_CONFIG`: make target, e.g. `defconfig`
- `KERNEL_CONFIG_1`, `KERNEL_CONFIG_2`: optional fragment paths relative to
  the source. **Empty means do not merge anything for that slot.**
  `repo:PATH` refers to a file in this repo.
- `KERNEL_ENABLE_Y`, `KERNEL_ENABLE_M`: explicitly requested Kconfig edits.
  Empty arrays do nothing.
- `KERNEL_LOCALVERSION` (conf/kernel.conf): the release label, applied via
  scripts/config with `CONFIG_LOCALVERSION_AUTO` off — byte-exact, every build.
- `KERNEL_DTB`, `KERNEL_IMAGE_TARGET`, `KERNEL_IMAGE_PATH`: source outputs.
- `KERNEL_BOOT_*`, `KERNEL_CMDLINE`: Android boot-image properties.

The default profile reproduces Channel's known settings, including the
`msm8953.config` fragment, CPR4PD and MSM8953 APCS clock support. One
`KERNELRELEASE` is pinned for the kernel build and `modules_install`, and both
outputs agree by construction. Rootfs builders reuse the published checkpoint
and never dispatch a kernel build themselves.

No workflow launches itself: the mainline kernel workflow stays manual, with
ccache enabled. For other devices, the scripts are reusable, but the rootfs and
boot-image pipeline must be adapted to the target device's boot partition and
rootfs layout.
