# AGENTS.md

## Project Purpose

SeaTurtleOS is the platform and device runtime for a browser-first marine appliance.
It runs on Raspberry Pi 4/5 and CM5-based hardware (HatLabs HalPi2). The stack is
fully containerized with Docker Compose and designed to operate **offline-first** —
zero internet required at runtime.

## Core Design Principles

- **Offline-first**: The flashable Pi image is fully self-contained. All Docker images
  pre-pulled, all configs baked in. Users may have no WAN access (common boat scenario).
- **Zero-touch boot**: Everything starts automatically. No manual scripts, no interactive
  setup beyond NPM/Portainer first-login flows. `docker compose up -d` and it works.
- **Local-network-first**: Services are accessed via browser on the vessel's LAN.
- **Reliability over elegance**: Prioritize persistence, clean power-loss recovery,
  and deterministic behavior.
- **Everything is a container**: No host-level application dependencies beyond Docker.
- **Bind mounts over volumes**: All data in `./data/` for visibility, portability,
  and Pi image baking.

## Rules

- Keep services containerized.
- Document architecture decisions in `docs/adr/`.
- Do not add GUI-first desktop dependencies.
- Favor Docker Compose for orchestration.
- Prefer simple, production-oriented solutions.
- Avoid unnecessary abstraction.
- No placeholder content — use real values or contextually appropriate defaults.

## Service Stack (10 services)

| Service | Container Name | Dev Port(s) | Image | Credentials |
|---------|---------------|-------------|-------|-------------|
| Landing Page | seaturtle-landing | 8080 | `nginx:1-alpine` | None |
| Status API | seaturtle-status-api | 8081 | `seaturtle/status-api:latest` (custom) | None |
| Nginx Proxy Manager | seaturtle-npm | 80, 443, 81 | `jc21/nginx-proxy-manager:2.14.0` | `admin@example.com` / `changeme` (forced change on first login) |
| Mosquitto (init) | seaturtle-mosquitto-init | — | `eclipse-mosquitto:2` | Transient — generates password file then exits |
| Mosquitto | seaturtle-mosquitto | 1883, 9001 | `eclipse-mosquitto:2` | `$SEATURTLE_MQTT_USER` / `$SEATURTLE_MQTT_PASSWORD` |
| Node-RED | seaturtle-nodered | 1880 | `nodered/node-red:4.1.8` | `admin` / `$SEATURTLE_INITIAL_PASSWORD` |
| Portainer | seaturtle-portainer | 9000 | `portainer/portainer-ce:2.27.3` | Set on first login (no env config) |
| Prometheus | seaturtle-prometheus | 9090 | `prom/prometheus:v3.4.0` | None |
| Signal K | seaturtle-signalk | 3000 | `seaturtle/signalk:latest` (custom) | Security disabled in dev |
| Grafana | seaturtle-grafana | 3001 (maps to internal 3000) | `grafana/grafana:11.6.0` | `admin` / `$SEATURTLE_INITIAL_PASSWORD` |

All services share the `seaturtle` Docker network.

### Custom-Built Images

Two services use custom Dockerfiles:

1. **seaturtle/signalk** (`deploy/compose/config/signalk/Dockerfile`): Extends
   `signalk/signalk-server:latest` with prebaked `signalk-mqtt-gw` plugin for
   offline-first boot. Uses `entrypoint.sh` to seed plugins from prebaked dir
   into bind-mounted volume on first boot.

2. **seaturtle/status-api** (`deploy/compose/config/status-api/Dockerfile`): Go
   sidecar that queries Docker Engine API over unix socket. Multi-stage build,
   8MB scratch image. Returns container status JSON at `GET /api/status`.

## Credential System

`SEATURTLE_INITIAL_PASSWORD` (default: `changeseaturtle`) flows to:

| Service | How It's Used |
|---------|---------------|
| Grafana | `GF_SECURITY_ADMIN_PASSWORD` env var |
| Node-RED | `bcryptjs.hashSync()` at startup in `settings.js` — zero manual steps |
| Mosquitto | Init container runs `mosquitto_passwd -b` to generate password file |
| Signal K MQTT | `entrypoint.sh` injects `MQTT_USER`/`MQTT_PASS` into plugin config via sed |

Services that **cannot** use env-based credentials:
- **NPM**: Built-in first-login flow (default `admin@example.com`/`changeme`)
- **Portainer**: Interactive first-login password creation
- **Prometheus**: No authentication support
- **Signal K**: Security disabled in dev mode

## Port Map (Dev)

```
80    — NPM HTTP
81    — NPM Admin GUI
443   — NPM HTTPS
1880  — Node-RED
1883  — MQTT TCP
3000  — Signal K
3001  — Grafana (remapped from internal 3000)
8080  — Landing Page
8081  — Status API
9000  — Portainer
9001  — MQTT WebSocket
9090  — Prometheus
```

Reserved for future: seaturtle-command (pick a non-colliding port, e.g., 4000, 5000, 8000).

## File Structure

```
deploy/compose/
  compose.base.yaml            # Dev Docker Compose (10 services, 272 lines)
  .env.example                 # Bootstrap env vars (copy to .env)
  .env                         # Gitignored local copy
  config/
    landing/                   # nginx.conf + index.html (status dashboard)
    mosquitto/                 # mosquitto.conf (auth enabled, TCP+WS)
    nodered/                   # settings.js (bcrypt adminAuth, MQTT creds)
    prometheus/                # prometheus.yaml (self-scrape + Grafana)
    signalk/                   # Dockerfile, entrypoint.sh, plugin-config-data
    status-api/                # main.go, go.mod, Dockerfile
  data/                        # Runtime data (gitignored, bind mounts)

docs/
  adr/
    0001-reverse-proxy-nginx-proxy-manager.md
    0002-subdomain-routing-scheme.md
    0003-signal-k-integration.md
  hardware/
    halpi2-profile.md          # HatLabs HalPi2 (CM5, 16GB, NVMe 1TB)
  testing/
    persistence-test-plan.md   # docker kill + power-loss test procedures
  superpowers/
    plans/
      2026-04-05-phases-2-6.md # Implementation plan (completed)

os/device-image/
  README.md                    # Build instructions
  builder/
    Dockerfile                 # rpi-image-gen build environment (Debian Bookworm)
  config/
    base.yaml                  # Shared: bookworm + Docker + seaturtle-services
    pi4.yaml                   # Pi 4, SD card
    pi5.yaml                   # Pi 5, SD card
    cm5-halpi2.yaml            # CM5/HalPi2, NVMe SSD
  layers/seaturtle-services/
    seaturtle-services.yaml    # rpi-image-gen layer definition
    rootfs-overlay/
      etc/systemd/system/      # seaturtle-preload-images.service, seaturtle-services.service
      opt/seaturtle/            # Production compose.yaml, .env, config/
      usr/local/bin/            # seaturtle-preload-images.sh
  scripts/
    pull-images.sh             # Builds + pulls all 9 images for arm64, saves tarball
    build-image.sh             # Invokes rpi-image-gen in Docker
  images/                      # Gitignored output (seaturtle-images.tar.gz, manifest.json)
  output/                      # Gitignored output (.img files)
```

## Development Workflow

### Start the stack (macOS / Linux)

```sh
cd deploy/compose
cp .env.example .env
docker compose -f compose.base.yaml up -d
```

Open http://localhost:8080 for the landing page.

### Rebuild custom images after changes

```sh
cd deploy/compose
docker compose -f compose.base.yaml build signalk status-api
docker compose -f compose.base.yaml up -d signalk status-api
```

### Reset all data

```sh
cd deploy/compose
docker compose -f compose.base.yaml down
rm -rf data/
docker compose -f compose.base.yaml up -d
```

### Build Pi image

```sh
cd os/device-image
./scripts/pull-images.sh           # Pre-pull all Docker images (~1.3 GB tarball)
./scripts/build-image.sh pi5       # Build for Pi 5 (or pi4, cm5-halpi2)
./scripts/build-image.sh --shell   # Drop into builder shell for debugging
```

## Pi Image Boot Flow (Offline)

1. First boot: `seaturtle-preload-images.service` runs `docker load` from
   `/opt/seaturtle/images/seaturtle-images.tar.gz`, then deletes the tarball
   to reclaim disk space. Uses `ConditionPathExists` so it only runs once.
2. Every boot: `seaturtle-services.service` runs `docker compose up -d` from
   `/opt/seaturtle/compose.yaml`.
3. Production compose exposes only NPM ports (80, 443, 81) + MQTT (1883).
   All other services accessed via NPM reverse proxy using `*.seaturtle.local`
   subdomains.

## Subdomain Routing Scheme (Pi / Production)

Per ADR 0002, production uses subdomain routing with `*.seaturtle.local`:

| Subdomain | Service |
|-----------|---------|
| `seaturtle.local` | Landing Page |
| `signalk.seaturtle.local` | Signal K |
| `nodered.seaturtle.local` | Node-RED |
| `grafana.seaturtle.local` | Grafana |
| `portainer.seaturtle.local` | Portainer |
| `prometheus.seaturtle.local` | Prometheus |

NPM routes configured manually via its GUI. SSL deferred to Phase 4+ (self-signed
wildcard CA for `*.seaturtle.local`).

## Target Hardware

- **Raspberry Pi 4** (4/8 GB) — SD card boot
- **Raspberry Pi 5** (4/8 GB) — SD card boot
- **HatLabs HalPi2** (CM5-based) — NVMe SSD boot, 16 GB RAM, 1 TB SSD, built-in
  NMEA 2000 + 0183, IP65 enclosure, 10-32V marine power supply, RP2040 graceful
  shutdown controller. See `docs/hardware/halpi2-profile.md`.

## Adding a New Service to the Stack

When integrating a new service (e.g., seaturtle-command):

1. **Pick a port** that doesn't collide with the port map above.
2. **Add to `deploy/compose/compose.base.yaml`** — join `seaturtle` network, add
   health check, use `restart: unless-stopped`, bind mount data to `./data/<service>/`.
3. **Add MQTT creds** if it talks to Mosquitto: `MQTT_USER`/`MQTT_PASS` env vars
   from `$SEATURTLE_MQTT_USER`/`$SEATURTLE_MQTT_PASSWORD`.
4. **Signal K API** from inside Docker network: `http://signalk:3000/signalk/v1/api/`,
   WebSocket: `ws://signalk:3000/signalk/v1/stream`.
5. **Update landing page** (`deploy/compose/config/landing/index.html`) — add a card.
6. **Update production compose** (`os/device-image/layers/seaturtle-services/rootfs-overlay/opt/seaturtle/compose.yaml`).
7. **Update `pull-images.sh`** — add the image to the pre-pull list.
8. **Update `README.md`** — add to service table and credentials table.
9. **Add subdomain** to ADR 0002 if needed (e.g., `command.seaturtle.local`).

## What's Deferred / Future Work

- **SSL certificates**: Self-signed wildcard CA for `*.seaturtle.local`. Currently
  all services run over HTTP on local network.
- **rpi-image-gen build testing**: Config files written but not yet tested end-to-end
  (requires Linux or Docker builder with `--privileged`).
- **Persistence test execution**: Test plan written at `docs/testing/persistence-test-plan.md`
  but not yet run.
- **NPM route configuration**: Manual GUI work per ADR 0002.
- **Signal K security**: Disabled in dev mode. Enable for production.
- **seaturtle-command**: Dashboard/control application (separate repository).

## Commit History

```
50a6866 fix: include factory .env in Pi image rootfs overlay
5136ffe feat: add Pi image building infrastructure (Phase 4)
196936e docs: add ADR 0002, persistence test plan, update README
9cf0e20 feat: landing page with live container status API
105975b feat: security hardening
ce42fce feat: prebake signalk-mqtt-gw plugin
1002cc2 feat: Signal-K marine data hub (Phase 3)
d8c068d feat: Phase 1 service stack
257b86c chore: initialize repository structure
```
