# ADR 0001: Nginx Proxy Manager as Reverse Proxy

## Status

Accepted

## Date

2026-04-05

## Context

SeaTurtleOS needs a reverse proxy to:

- Route browser traffic to containerized services (Node-RED, Grafana, Portainer, etc.)
- Manage TLS certificates (self-signed for local networks, Let's Encrypt for public DNS)
- Provide access control (basic auth, IP restrictions)

The target users are boat owners, not sysadmins. The proxy must be manageable through
a browser GUI without editing config files or Docker labels.

### Options Evaluated

1. **Nginx Proxy Manager (NPM)** — Full read-write GUI for proxy hosts, SSL, access
   lists, and user management. MIT license, 32k+ GitHub stars, official arm64 image.
   Uses ~150-200 MB RAM. Backed by Nginx + Node.js + SQLite.

2. **Traefik + built-in dashboard** — Lightweight (~30-50 MB RAM), excellent Docker
   auto-discovery via labels. However, the dashboard is **strictly read-only** (GET
   endpoints only — no POST/PUT/DELETE). Routes can only be created via Docker labels
   or config files. Not viable for non-technical end users.

3. **Traefik + third-party GUI** — No mature open-source GUI exists for editing Traefik
   routes. Traefik Hub (commercial) requires cloud connectivity, which violates the
   offline-first constraint. The architectural barrier is Traefik's read-only API.

## Decision

Use **Nginx Proxy Manager** (`jc21/nginx-proxy-manager`).

## Rationale

- **GUI route management** is the deciding factor. NPM is the only option where end
  users can create, edit, and delete proxy hosts, SSL certificates, and access lists
  entirely through a browser.
- **~200 MB RAM** on a Pi 4/5 with 4-8 GB is ~2.5-5% of available memory. Acceptable.
- **SQLite with WAL mode** survives power loss cleanly — important for a marine appliance.
- **Explicit routing** (manual GUI entry) suits a fixed-service appliance better than
  auto-discovery. Every route is visible and intentional.
- **Zero cloud dependency.** Everything runs locally.

## Consequences

- Routes are configured manually via the NPM GUI, not auto-discovered from Docker.
  This means adding a new service requires a manual proxy host entry. For a stable
  appliance with a known service set, this is a feature, not a limitation.
- NPM's default admin credentials (`admin@example.com` / `changeme`) are not
  configurable via environment variables. First login forces a password change.
- If SeaTurtleOS later builds a custom management UI, migrating to Traefik with
  programmatic label-based routing becomes an option. NPM is not a permanent lock-in.
