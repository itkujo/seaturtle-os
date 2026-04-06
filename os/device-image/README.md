# SeaTurtleOS — Device Image

## Strategy: Offline-First

The flashable Raspberry Pi image must be **fully self-contained with zero internet
required at runtime**. The typical deployment scenario:

1. User downloads the SeaTurtleOS image on a laptop (with internet)
2. Flashes the image to an SD card or NVMe
3. Installs the card into a Pi on a boat — which may have **no WAN access**

### What "offline-first" means for image building

- **All Docker images pre-pulled** and saved into the image (e.g., via
  `docker save` / `docker load` or embedded in the filesystem)
- **All service configs baked in** — Compose files, Mosquitto config, Prometheus
  config, Node-RED settings, etc.
- **No package manager calls at boot** — no `apt update`, no `npm install`
- **No cloud-dependent features** — no Traefik Hub, no remote registries,
  no call-home telemetry

### Image builder

We use [`rpi-image-gen`](https://github.com/raspberrypi/rpi-image-gen)
(official Raspberry Pi org tool) to build reproducible, customized images that include:

- Base OS (Raspberry Pi OS Lite, 64-bit)
- Docker Engine + Compose plugin
- Pre-pulled container images for the full service stack
- System configuration (networking, hostname, systemd units)
- First-boot scripts for initial setup

### Current status

This directory is a placeholder. Image building will be implemented after the
service stack is validated on macOS (Apple Silicon arm64 containers match Pi arch).

### Target hardware

- Raspberry Pi 4 (4 GB / 8 GB)
- Raspberry Pi 5 (4 GB / 8 GB)
- Raspberry Pi CM5 (custom carrier boards)
