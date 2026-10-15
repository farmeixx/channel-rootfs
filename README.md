# Channel Alpine rootfs

Moto G7 Play (channel) alpine rootfs, shell-based. This branch reuses the existing
mainline kernel checkpoint **exclusively**; it never compiles or dispatches
another kernel from a rootfs workflow.

The firmware required for Channel Wi-Fi is included in `firmware/channel/`.
No per-device extraction or Android firmware mount is required. The checked-in
script `scripts/firmware/channel.sh` verifies and installs the blobs.

For local Linux builds, after obtaining a valid checkpoint in
`out/kernel/checkpoint/`, run:

```sh
bash alpine/run.sh
```

In GitHub Actions, this branch's workflow runs
`bash scripts/ci/build-rootfs.sh alpine`, downloading a **successful existing**
`mainline.yml` checkpoint from branch `main`. The newest successful
kernel run with an unexpired checkpoint artifact is selected automatically;
there is no run ID input. If none is available, the rootfs workflow fails.
The YAML defines only triggers, permissions, invocation, and artifact uploads.

**Run workflow: select the `alpine` branch**, not `main` or another distribution. This workflow reuses only a previously successful mainline kernel checkpoint; it does not compile or dispatch the kernel.
