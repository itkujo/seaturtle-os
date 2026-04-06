# SeaTurtleOS

SeaTurtleOS is an open-source marine appliance platform for Raspberry Pi and CM5-based vessel computers.

## Goals

- Browser-first local vessel access
- Containerized service stack
- Signal K, MQTT, Node-RED, Portainer, Prometheus, and Grafana support
- Power-failure-aware device image design
- Foundation for SeaTurtle Command

## Service Stack

| Service | Dev Port | Purpose |
|---------|----------|---------|
| [Nginx Proxy Manager](https://nginxproxymanager.com/) | 80, 443, 81 | Reverse proxy with GUI management |
| [Mosquitto](https://mosquitto.org/) | 1883, 9001 | MQTT broker (TCP + WebSocket) |
| [Node-RED](https://nodered.org/) | 1880 | Flow-based automation engine |
| [Portainer](https://www.portainer.io/) | 9000 | Docker container management GUI |
| [Prometheus](https://prometheus.io/) | 9090 | Metrics collection and storage |
| [Grafana](https://grafana.com/) | 3000 | Dashboards and visualization |

## Quick Start

### Prerequisites

- Docker Engine 24+ with Compose plugin
- macOS (Apple Silicon) or Linux (arm64/amd64)

### Start the stack

```sh
cd deploy/compose
cp .env.example .env        # adjust SEATURTLE_INITIAL_PASSWORD if desired
docker compose -f compose.base.yaml up -d
```

### First-login credentials

| Service | Username | Password | Notes |
|---------|----------|----------|-------|
| Nginx Proxy Manager | `admin@example.com` | `changeme` | Forced password change on first login |
| Node-RED | — | — | Secured by `credentialSecret` (not a login) |
| Portainer | — | — | Interactive first-login setup |
| Grafana | `admin` | Value of `SEATURTLE_INITIAL_PASSWORD` | Default: `changeseaturtle` |

### View logs

```sh
cd deploy/compose
docker compose -f compose.base.yaml logs -f          # all services
docker compose -f compose.base.yaml logs -f grafana   # single service
```

### Stop the stack

```sh
cd deploy/compose
docker compose -f compose.base.yaml down
```

### Reset all data

```sh
cd deploy/compose
docker compose -f compose.base.yaml down
rm -rf data/
docker compose -f compose.base.yaml up -d
```

## Project Structure

```
deploy/compose/
  compose.base.yaml          # Docker Compose service definitions
  .env.example               # Bootstrap environment variables
  config/                    # Service configuration files (read-only mounts)
    mosquitto/mosquitto.conf
    prometheus/prometheus.yaml
    nodered/settings.js
  data/                      # Runtime data (bind mounts, gitignored)
docs/adr/                    # Architecture Decision Records
os/device-image/             # Raspberry Pi image build tooling (future)
```

## Architecture Decisions

- [ADR 0001: Nginx Proxy Manager as Reverse Proxy](docs/adr/0001-reverse-proxy-nginx-proxy-manager.md)

## Status

Early setup and architecture phase.
