# SeaTurtleOS

SeaTurtleOS is an open-source marine appliance platform for Raspberry Pi and CM5-based vessel computers.

## Goals

- Browser-first local vessel access
- Containerized service stack
- Signal K, MQTT, Node-RED, Portainer, Prometheus, and Grafana support
- Power-failure-aware device image design
- Offline-first: zero internet required at runtime
- Foundation for SeaTurtle Command

## Service Stack

| Service | Dev Port | Purpose |
|---------|----------|---------|
| [Landing Page](deploy/compose/config/landing/) | 8080 | Service directory and default credentials |
| [Nginx Proxy Manager](https://nginxproxymanager.com/) | 80, 443, 81 | Reverse proxy with GUI management |
| [Signal K](https://signalk.org/) | 3000 | Marine data hub (NMEA 2000 / 0183) |
| [Mosquitto](https://mosquitto.org/) | 1883, 9001 | MQTT broker (TCP + WebSocket) |
| [Node-RED](https://nodered.org/) | 1880 | Flow-based automation engine |
| [Grafana](https://grafana.com/) | 3001 | Dashboards and visualization |
| [Prometheus](https://prometheus.io/) | 9090 | Metrics collection and storage |
| [Portainer](https://www.portainer.io/) | 9000 | Docker container management GUI |

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

Open http://localhost:8080 for the landing page with all service links.

### Default Credentials

| Service | Username | Password | Notes |
|---------|----------|----------|-------|
| Nginx Proxy Manager | `admin@example.com` | `changeme` | Forced change on first login |
| Grafana | `admin` | `changeseaturtle` | Value of `SEATURTLE_INITIAL_PASSWORD` |
| Node-RED | `admin` | `changeseaturtle` | Value of `SEATURTLE_INITIAL_PASSWORD` |
| MQTT (Mosquitto) | `seaturtle` | `changeseaturtle` | Value of `SEATURTLE_MQTT_PASSWORD` |
| Portainer | — | — | Set on first login |
| Signal K | — | — | Security disabled in dev mode |
| Prometheus | — | — | No authentication |

### View logs

```sh
cd deploy/compose
docker compose -f compose.base.yaml logs -f          # all services
docker compose -f compose.base.yaml logs -f signalk   # single service
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
    landing/                 # Landing page (nginx + static HTML)
    mosquitto/               # MQTT broker config
    nodered/                 # Node-RED settings
    prometheus/              # Prometheus scrape config
    signalk/                 # Signal K Dockerfile + MQTT plugin
  data/                      # Runtime data (bind mounts, gitignored)
docs/
  adr/                       # Architecture Decision Records
  hardware/                  # Hardware profiles (HalPi2, etc.)
  testing/                   # Test plans
os/device-image/             # Raspberry Pi image build tooling (future)
```

## Architecture Decisions

- [ADR 0001: Nginx Proxy Manager as Reverse Proxy](docs/adr/0001-reverse-proxy-nginx-proxy-manager.md)
- [ADR 0002: Subdomain Routing Scheme](docs/adr/0002-subdomain-routing-scheme.md)
- [ADR 0003: Signal K Integration](docs/adr/0003-signal-k-integration.md)

## Status

Service stack validated on macOS (Apple Silicon arm64). Next: Pi image building.
