# Generic mainline kernel builder

Configure **conf/mainline.conf** at the repository root before running:

```bash
bash sh/run.sh
```

The shared scripts do not contain Channel source URLs, kernel branches, config
fragments, DTB paths, required Kconfig symbols or boot-image offsets. All are
configured in `conf/mainline.conf`.

Important options:
- `KERNEL_URL`: git clone URL
- `KERNEL_REF`: branch to clone
- `KERNEL_CLONE_DIR`: local clone path beneath `.work/`
- `KERNEL_BASE_CONFIG`: make target, e.g. `defconfig`
- `KERNEL_CONFIG_1`, `KERNEL_CONFIG_2`: optional fragment paths relative to
  the source. **Empty means do not merge anything for that slot.**
  `repo:PATH` can refer to a local file in this builder repo.
- `KERNEL_ENABLE_Y`, `KERNEL_ENABLE_M`: explicitly requested Kconfig edits.
  Empty arrays do nothing.
- `KERNEL_DTB`, `KERNEL_IMAGE_TARGET`, `KERNEL_IMAGE_PATH`: source outputs.
- `KERNEL_REQUIRE_Y/M`: per-device sanity validation.
- `KERNEL_DTB_CHECK_*`: optional device DTB sanity check.
- `KERNEL_BOOT_*`, `KERNEL_CMDLINE`: Android boot-image properties.
  
The default profile reproduces Channel's known settings, including the
`msm8953.config` fragment, CPR4PD and MSM8953 APCS clock support.

No workflow is launched from any rootfs builder. The mainline kernel workflow
remains manual, with ccache enabled. The previous checkpoint is kept until a
new one successfully builds and verifies. For other devices, build scripts
are reusable, but the rootfs/boot image pipeline must also be adapted to the
target device's boot partition and rootfs layout.


## Kernel/module release consistency

A checkpoint is accepted only when `kernel-release.txt`, the version embedded
in `Image.gz`, the `lib/modules/<release>/` archive path, and every module's
ELF `vermagic` agree. The build pins one `KERNELRELEASE` for kernel compilation
and `modules_install`; validation fails closed if the compiled image or any
module disagrees. The boot image's unpacked kernel payload is also compared with
the exact `Image.gz` + DTB payload used to create it. Rootfs workflows repeat
the image/module checks before using a checkpoint and never dispatch a kernel
build themselves.
