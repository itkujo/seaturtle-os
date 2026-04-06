# Persistence & Recovery Test Plan

## Objective

Verify that all SeaTurtleOS services recover cleanly after abrupt shutdown
(power loss simulation) with no data loss and no manual intervention.

## Test Environment

| Platform | Simulation Method |
|----------|-------------------|
| macOS (Docker Desktop) | `docker kill` (SIGKILL, no graceful shutdown) |
| Raspberry Pi 4/5 | Physical power disconnect |

## Pre-Test Setup

1. Start the full stack: `docker compose -f compose.base.yaml up -d`
2. Wait for all containers to report healthy
3. Create test data in each service (see checklist below)

## Test Data Checklist

| Service | Test Data to Create | Persistence Path |
|---------|---------------------|------------------|
| Signal K | Verify sample data stream is active | `./data/signalk/` |
| Node-RED | Deploy a simple flow (e.g., inject → debug) | `./data/nodered/flows.json` |
| Grafana | Create a dashboard with one panel | `./data/grafana/grafana.db` |
| Mosquitto | Publish a retained message | `./data/mosquitto/data/` |
| Prometheus | Wait 2+ minutes for scrape data accumulation | `./data/prometheus/` |
| Portainer | Complete initial admin setup | `./data/portainer/` |
| NPM | Create one proxy host entry | `./data/npm/data/` |

## Test Procedure

### Phase A: Abrupt Kill (macOS)

```bash
# 1. Kill all containers without graceful shutdown
docker kill $(docker ps -q --filter "name=seaturtle-")

# 2. Verify all containers are stopped
docker ps --filter "name=seaturtle-"

# 3. Restart the stack
docker compose -f compose.base.yaml up -d

# 4. Wait for health checks to pass
docker compose -f compose.base.yaml ps
```

### Phase B: Service-Level Kill

Test each service individually to verify independent recovery:

```bash
# Kill one service at a time
docker kill seaturtle-nodered
docker compose -f compose.base.yaml up -d nodered

# Repeat for each service:
# seaturtle-mosquitto, seaturtle-grafana, seaturtle-signalk,
# seaturtle-prometheus, seaturtle-portainer, seaturtle-npm
```

### Phase C: Pi Hardware Test

1. Boot Pi with SeaTurtleOS image
2. Create test data in all services
3. Pull power cable (no shutdown command)
4. Reconnect power
5. Wait for boot + Docker startup
6. Verify all services and data

## Verification Checklist

After restart, verify each item:

- [ ] **All containers running**: `docker compose ps` shows all services "Up" and healthy
- [ ] **Landing page**: http://localhost:8080 loads correctly
- [ ] **NPM**: http://localhost:81 responds, proxy host entries preserved
- [ ] **Signal K**: http://localhost:3000 responds, data stream active
- [ ] **Node-RED**: http://localhost:1880 loads, deployed flow still present
- [ ] **Grafana**: http://localhost:3001 loads, dashboard still present
- [ ] **Mosquitto**: Retained messages still available (`mosquitto_sub -t test/# -C 1`)
- [ ] **Prometheus**: Historical metrics visible in graph (data not wiped)
- [ ] **Portainer**: http://localhost:9000 loads, admin account persists
- [ ] **mosquitto-init**: Does NOT regenerate password file (skips if exists)

## Known Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| SQLite corruption (NPM, Grafana) | Both use WAL mode by default — crash-safe |
| Prometheus TSDB corruption | Prometheus has built-in WAL recovery on startup |
| Mosquitto persistence DB | Mosquitto flushes on clean shutdown; SIGKILL may lose in-flight messages but retained messages survive |
| Node-RED flow save | Flows saved to disk on deploy; in-flight data lost on kill is expected |
| Docker overlay filesystem corruption | Extremely rare on ext4/btrfs; rebuild container if needed |

## Pass Criteria

- All containers reach "healthy" state within 2 minutes of restart
- All test data created before the kill is present after restart
- No manual intervention required (no config fixes, no data recovery)
- `mosquitto-init` skips password generation on restart (idempotent)
