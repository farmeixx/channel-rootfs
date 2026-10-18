# Motorola Moto G7 Play (channel) rootfs

The **rootfs** branch builds Alpine, Debian and Ubuntu using an existing mainline
kernel checkpoint. Firmware is stored locally as the complete Channel source
archive and installed by the shared script.

## Organized layout

```text
conf/
  firmware.conf              # Source, destination and per-driver firmware aliases
  usb.conf                   # USB RNDIS and SSH device identity
sh/
  build.sh                   # CI entry: fetch an existing kernel checkpoint
  fetch-kernel.sh            # Find/download successful mainline artifact
  run.sh                     # Orchestrate an individual distro build
  validate.sh                # Check reused Channel kernel checkpoint
  firmware.sh                # Install full firmware tree from conf/
  usb-gadget                 # RNDIS ConfigFS implementation installed in rootfs
  deps.sh                    # Build machine requirements
common/
  rootfs/                    # Shared NetworkManager configuration (all 3)
  systemd/rootfs/            # Shared services and SSH config (Debian & Ubuntu)
alpine/
  build.sh                   # Alpine-specific builder
  rootfs/                    # OpenRC and Alpine-specific overlay
debian/
  build.sh                   # Debian-specific builder
ubuntu/
  build.sh                   # Ubuntu-specific builder
audio/rootfs/                # ALSA UCM and PulseAudio initialization
firmware/channel/source/     # All imported modem, WCNSS, ADSP, GPU, touchscreen, NV
docs/firmware.md             # Firmware details
```

## Building

Run **Build alpine rootfs**, **Build debian rootfs**, or **Build ubuntu rootfs**
from the main branch GitHub Actions tab. They check out this `rootfs` branch
and run `bash sh/build.sh DISTRO`.

A rootfs job never compiles or dispatches the kernel. It downloads the newest
successful and unexpired `mainline.yml` checkpoint, then validates it.

For local builds with a checkpoint in `out/kernel/checkpoint`:

```sh
bash sh/run.sh alpine
bash sh/run.sh debian
bash sh/run.sh ubuntu
```

Outputs are saved under `out/rootfs/DISTRO/`: `rootfs.ext4`, the compressed
`DISTRO-channel-rootfs.ext4.zst`, `boot.img` copied from the kernel checkpoint,
build metadata and SHA256SUMS. All three currently use 1024 MiB ext4 images.

## Channel integration

- Firmware: `conf/firmware.conf` + `sh/firmware.sh`; no GitLab download needed
  when `firmware/channel/source/` is present. Drivers receive their required paths.
- USB RNDIS: `conf/usb.conf` + `sh/usb-gadget` (installed inside the rootfs).
  SSH listens on `172.16.42.1`; DHCP assigns `172.16.42.2–20`.
- Wi-Fi: NetworkManager manages wlan0 but leaves USB `usb0` unmanaged.
- Audio: shared UCM2 profile and PulseAudio helper. Headphones worked on
  Alpine; speaker/mic and Debian/Ubuntu runtime are not yet validated.

See [firmware documentation](docs/firmware.md).
