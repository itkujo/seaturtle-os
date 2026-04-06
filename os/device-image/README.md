# SeaTurtleOS — Device Image

## Strategy: Offline-First

The flashable Raspberry Pi image must be **fully self-contained with zero internet
required at runtime**. The typical deployment scenario:

1. User downloads the SeaTurtleOS image on a laptop (with internet)
2. Flashes the image to an SD card or NVMe
3. Installs the card into a Pi on a boat — which may have **no WAN access**

### What "offline-first" means for image building

- **All Docker images pre-pulled** and baked into the filesystem
- **All service configs baked in** — Compose files, Mosquitto config, Prometheus
  config, Node-RED settings, etc.
- **No package manager calls at boot** — no `apt update`, no `npm install`
- **No cloud-dependent features** — no remote registries, no call-home telemetry

## Image Builder

We use [`rpi-image-gen`](https://github.com/raspberrypi/rpi-image-gen)
(official Raspberry Pi org tool, BSD-3-Clause) to build reproducible, customized
images. The build runs inside a Docker container on macOS (Apple Silicon) or Linux.

## Directory Structure

```
os/device-image/
├── builder/              # Dockerfile for the rpi-image-gen build environment
│   └── Dockerfile
├── config/               # rpi-image-gen YAML configs
│   ├── base.yaml         # Shared config (layers, user, hostname)
│   ├── pi4.yaml          # Pi 4 (SD card)
│   ├── pi5.yaml          # Pi 5 (SD card)
│   └── cm5-halpi2.yaml   # CM5 / HalPi2 (NVMe SSD)
├── layers/
│   └── seaturtle-services/
│       ├── seaturtle-services.yaml   # rpi-image-gen layer definition
│       └── rootfs-overlay/           # Files baked into the image filesystem
│           ├── etc/systemd/system/   # Systemd units
│           ├── opt/seaturtle/        # Compose stack + configs
│           └── usr/local/bin/        # First-boot scripts
├── scripts/
│   ├── pull-images.sh    # Pre-pull Docker images for offline deployment
│   └── build-image.sh    # Build Pi image using rpi-image-gen in Docker
├── images/               # (gitignored) Pre-pulled image tarballs
└── output/               # (gitignored) Built .img files
```

## Quick Start

### 1. Pre-pull Docker images

```bash
# Builds custom images (signalk, status-api) for arm64 and pulls
# all registry images. Outputs a tarball to images/
./scripts/pull-images.sh
```

### 2. Build a Pi image

```bash
# Build for a specific device
./scripts/build-image.sh pi5           # Pi 5 (SD card)
./scripts/build-image.sh pi4           # Pi 4 (SD card)
./scripts/build-image.sh cm5-halpi2    # CM5 / HalPi2 (NVMe SSD)

# List available profiles
./scripts/build-image.sh --list

# Debug — drop into the builder container
./scripts/build-image.sh --shell
```

### 3. Flash the image

```bash
# macOS (replace /dev/diskN with your SD card)
sudo dd if=output/pi5-seaturtle-os.img of=/dev/rdiskN bs=1m status=progress
```

Or use [Raspberry Pi Imager](https://www.raspberrypi.com/software/) to flash
the `.img` file.

## Boot Sequence (on Pi)

1. **First boot**: `seaturtle-preload-images.service` loads Docker images from
   the pre-pulled tarball into Docker's local store, then deletes the tarball
   to reclaim disk space (~1-2 GB).
2. **Every boot**: `seaturtle-services.service` runs `docker compose up -d` to
   start the full service stack.
3. Services are accessible via the landing page at `http://seaturtle.local`.

## Target Hardware

| Device | Storage | Config |
|--------|---------|--------|
| Raspberry Pi 4 (4/8 GB) | SD card | `pi4.yaml` |
| Raspberry Pi 5 (4/8 GB) | SD card | `pi5.yaml` |
| CM5 / HalPi2 (16 GB) | NVMe SSD (1 TB) | `cm5-halpi2.yaml` |

See `docs/hardware/halpi2-profile.md` for HalPi2 details.

## Build Environment Requirements

- Docker with buildx support (Docker Desktop or buildx plugin)
- macOS (Apple Silicon) — native arm64, fast builds
- macOS (Intel) or Linux x86_64 — works via QEMU, slower
- Linux arm64 — native, fastest
