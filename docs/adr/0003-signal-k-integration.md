# ADR 0003: Signal K as Marine Data Hub

## Status

Accepted

## Date

2026-04-05

## Context

SeaTurtleOS needs to ingest, normalize, and distribute marine instrument data
from NMEA 2000 and NMEA 0183 networks. Signal K is the open-source standard
for this role.

### Signal K Server

- **Image**: `signalk/signalk-server` (also at `cr.signalk.io/signalk/signalk-server`)
- **Version**: v2.24.0 (March 2026), Ubuntu 24.04 LTS base
- **License**: Apache 2.0
- **ARM64**: Fully supported (multi-arch manifest)
- **RAM**: ~80-150 MB idle, ~150-300 MB typical

### Capabilities

- REST API: `http://<host>:3000/signalk/v1/api/`
- WebSocket streaming: `ws://<host>:3000/signalk/v1/stream`
- Admin UI with plugin management (Appstore)
- NMEA 0183 TCP input/output (port 10110)
- NMEA 2000 via CAN bus or gateway
- Simulated data for development (`--sample-nmea0183-data`)

### MQTT Integration

The `signalk-mqtt-gw` plugin (by core maintainer Teppo Kurki) connects Signal K
to an external MQTT broker. It publishes SK deltas to MQTT topics and can receive
data from MQTT. Installed from the Signal K Admin UI Appstore.

## Decision

Use **Signal K Server** as the marine data hub, with the `signalk-mqtt-gw` plugin
bridging data to Mosquitto for consumption by Node-RED and other services.

## Rationale

- Signal K is the de facto open standard for marine data
- The Docker image has native arm64 support
- Development mode with simulated data enables work without a boat
- The MQTT gateway plugin enables loose coupling with the rest of the stack
- Plugin ecosystem covers AIS, anchor watch, weather, and more

## Consequences

- Signal K takes port 3000 (Grafana remapped to host port 3001 in dev)
- The `signalk-mqtt-gw` plugin must be installed manually via the Admin UI
  Appstore after first boot — it cannot be pre-installed via environment variables
- Development uses `--sample-nmea0183-data`; production uses real NMEA connections
  configured through the Signal K Admin UI
