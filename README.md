# Moto G7 Play (channel) — unified rootfs builders

This `rootfs` branch contains **Alpine, Debian and Ubuntu** for Channel. The three distro builders have independent directories; common tooling and the Channel firmware are shared once.

## Layout

- `alpine/build.sh`, `alpine/run.sh`, `alpine/rootfs/`: Alpine builder and overlays.
- `debian/build.sh`, `debian/run.sh`, `debian/rootfs/`: Debian builder and overlays.
- `ubuntu/build.sh`, `ubuntu/run.sh`, `ubuntu/rootfs/`: Ubuntu builder and overlays.
- `scripts/ci/build-rootfs.sh`: selects one distribution, then reuses an existing kernel checkpoint.
- `scripts/ci/fetch-kernel.sh`: downloads the newest successful unexpired kernel checkpoint from the **main** branch. Never dispatches or rebuilds a kernel.
- `scripts/rootfs/run.sh`, `scripts/host-deps.sh`, `scripts/kernel/validate.sh`: shared rootfs build support.
- `scripts/firmware/channel.sh`, `firmware/channel/`: one verified copy of Channel firmware for all three builders.

## GitHub Actions

Select **Build alpine rootfs**, **Build debian rootfs**, or **Build ubuntu rootfs** from the repository Actions tab, using branch **main**. Their lightweight YAML entry points live on `main`, check out this `rootfs` branch, and call:

```bash
bash scripts/ci/build-rootfs.sh alpine  # or debian / ubuntu
```

Rootfs workflows reuse the latest **successful, unexpired** kernel checkpoint from `mainline.yml` on `main`. If none exists, they fail rather than starting a kernel build. The kernel builder and ccache remain on `main`.

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
