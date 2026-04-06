# ADR 0002: Subdomain Routing Scheme

## Status

Accepted

## Date

2026-04-05

## Context

SeaTurtleOS runs multiple web services that need to be accessible through a
single reverse proxy (Nginx Proxy Manager, see ADR 0001). Two routing
approaches were considered:

1. **Path-based**: `seaturtle.local/grafana`, `seaturtle.local/nodered`, etc.
2. **Subdomain-based**: `grafana.seaturtle.local`, `nodered.seaturtle.local`, etc.

### Path-based routing issues

Several services (Grafana, Node-RED, Portainer, Signal K) assume they are
served at the root path `/`. Making them work behind a path prefix requires:

- Custom `root_url` / `base_path` configuration per service
- Rewriting of internal asset paths, WebSocket endpoints, and API routes
- Fragile maintenance as upstream updates may break path assumptions
- Some services (Portainer, Signal K) have incomplete or no sub-path support

### Subdomain-based routing advantages

- Each service gets its own root `/` — no path rewriting needed
- Standard HTTP `Host` header routing — universally supported
- Clean separation of concerns
- Simple NPM configuration: one proxy host per service

### SSL with subdomains

On `.local` mDNS domains, Let's Encrypt is not available. The solution is a
self-signed wildcard CA certificate:

- Generate one CA + wildcard cert for `*.seaturtle.local`
- Users install the CA certificate once on their devices
- All subdomains are covered by a single certificate
- NPM serves the wildcard cert for all proxy hosts

SSL certificate generation is deferred to Phase 4 (Pi image building) where
certs can be baked into the image and NPM's SQLite pre-configured.

## Decision

Use subdomain-based routing with `*.seaturtle.local`.

### Subdomain Mapping

| Subdomain | Service | Internal Target |
|-----------|---------|-----------------|
| `seaturtle.local` | Landing page | `landing:8080` |
| `npm.seaturtle.local` | Nginx Proxy Manager | `nginx-proxy-manager:81` |
| `signalk.seaturtle.local` | Signal K | `signalk:3000` |
| `nodered.seaturtle.local` | Node-RED | `nodered:1880` |
| `grafana.seaturtle.local` | Grafana | `grafana:3000` |
| `prometheus.seaturtle.local` | Prometheus | `prometheus:9090` |
| `portainer.seaturtle.local` | Portainer | `portainer:9000` |

### Development (macOS)

During development, services are accessed directly via `localhost:<port>`.
Subdomain routing through NPM is configured manually via the NPM GUI when
needed. No `/etc/hosts` entries or mDNS setup required for basic development.

### Production (Pi image)

On the Pi, only NPM ports 80/443 are exposed to the network. All other service
ports are internal to the Docker network. The Pi advertises `seaturtle.local`
via mDNS (Avahi). Users access services through subdomains only.

## Consequences

- NPM proxy hosts must be created manually through the GUI (one per service)
- Each service's `root_url` / `external_url` should reference its subdomain
- A wildcard DNS or mDNS entry is needed on the Pi (handled by Avahi + dnsmasq)
- Browser clients need the CA certificate installed for HTTPS without warnings
- Adding a new service requires creating one NPM proxy host entry
