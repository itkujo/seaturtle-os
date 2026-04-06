#!/usr/bin/env bash
# SeaTurtleOS — Pre-pull and package all Docker images for offline Pi deployment.
#
# Usage:
#   ./pull-images.sh                  # Pull + build all images, save tarball
#   ./pull-images.sh --skip-build     # Pull only (skip custom image builds)
#   ./pull-images.sh --output /path   # Custom output directory
#
# Requires: Docker with buildx support (Docker Desktop or buildx plugin).
# Runs on macOS (Apple Silicon) or Linux. Targets linux/arm64.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
COMPOSE_DIR="$REPO_ROOT/deploy/compose"
OUTPUT_DIR="$SCRIPT_DIR/../images"
PLATFORM="linux/arm64"
SKIP_BUILD=false

# ── Parse arguments ──────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-build) SKIP_BUILD=true; shift ;;
    --output) OUTPUT_DIR="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--skip-build] [--output /path]"
      echo ""
      echo "Pre-pulls and packages all SeaTurtleOS Docker images for offline deployment."
      echo ""
      echo "Options:"
      echo "  --skip-build   Skip building custom images (signalk, status-api)"
      echo "  --output DIR   Output directory for tarball (default: os/device-image/images/)"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

mkdir -p "$OUTPUT_DIR"

# ── Image list ───────────────────────────────────────────────────
# Registry images — exact tags from compose.base.yaml
REGISTRY_IMAGES=(
  "jc21/nginx-proxy-manager:2.14.0"
  "eclipse-mosquitto:2"
  "nodered/node-red:4.1.8"
  "portainer/portainer-ce:2.27.3"
  "prom/prometheus:v3.4.0"
  "grafana/grafana:11.6.0"
  "nginx:1-alpine"
)

# Custom-built images
CUSTOM_IMAGES=(
  "seaturtle/signalk:latest"
  "seaturtle/status-api:latest"
)

ALL_IMAGES=("${REGISTRY_IMAGES[@]}" "${CUSTOM_IMAGES[@]}")

# ── Helper functions ─────────────────────────────────────────────
log() { echo "==> $*"; }
err() { echo "ERROR: $*" >&2; exit 1; }

check_docker() {
  command -v docker >/dev/null 2>&1 || err "Docker is not installed"
  docker info >/dev/null 2>&1 || err "Docker daemon is not running"
}

# ── Build custom images ─────────────────────────────────────────
build_custom_images() {
  if [[ "$SKIP_BUILD" == "true" ]]; then
    log "Skipping custom image builds (--skip-build)"
    return
  fi

  log "Building custom images for $PLATFORM..."

  log "Building seaturtle/signalk:latest"
  docker buildx build \
    --platform "$PLATFORM" \
    --tag "seaturtle/signalk:latest" \
    --load \
    -f "$COMPOSE_DIR/config/signalk/Dockerfile" \
    "$COMPOSE_DIR/config/signalk"

  log "Building seaturtle/status-api:latest"
  docker buildx build \
    --platform "$PLATFORM" \
    --tag "seaturtle/status-api:latest" \
    --load \
    -f "$COMPOSE_DIR/config/status-api/Dockerfile" \
    "$COMPOSE_DIR/config/status-api"

  log "Custom images built."
}

# ── Pull registry images ────────────────────────────────────────
pull_registry_images() {
  log "Pulling registry images for $PLATFORM..."

  for img in "${REGISTRY_IMAGES[@]}"; do
    log "  Pulling $img"
    docker pull --platform "$PLATFORM" "$img"
  done

  log "All registry images pulled."
}

# ── Save all images to tarball ───────────────────────────────────
save_images() {
  local tarball="$OUTPUT_DIR/seaturtle-images.tar.gz"

  log "Saving ${#ALL_IMAGES[@]} images to tarball..."
  log "  Images: ${ALL_IMAGES[*]}"

  # docker save outputs a tar stream; pipe through gzip
  docker save "${ALL_IMAGES[@]}" | gzip -1 > "$tarball"

  local size
  size=$(du -h "$tarball" | cut -f1)
  log "Tarball saved: $tarball ($size)"
}

# ── Generate manifest ───────────────────────────────────────────
generate_manifest() {
  local manifest="$OUTPUT_DIR/manifest.json"

  log "Generating image manifest..."

  echo "{" > "$manifest"
  echo "  \"generated\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"," >> "$manifest"
  echo "  \"platform\": \"$PLATFORM\"," >> "$manifest"
  echo "  \"images\": [" >> "$manifest"

  local first=true
  for img in "${ALL_IMAGES[@]}"; do
    local digest
    digest=$(docker inspect --format='{{index .RepoDigests 0}}' "$img" 2>/dev/null || echo "local-build")
    local img_size
    img_size=$(docker inspect --format='{{.Size}}' "$img" 2>/dev/null || echo "0")

    if [[ "$first" == "true" ]]; then
      first=false
    else
      echo "    ," >> "$manifest"
    fi

    printf '    {"image": "%s", "digest": "%s", "size": %s}' "$img" "$digest" "$img_size" >> "$manifest"
  done

  echo "" >> "$manifest"
  echo "  ]" >> "$manifest"
  echo "}" >> "$manifest"

  log "Manifest saved: $manifest"
}

# ── Main ─────────────────────────────────────────────────────────
main() {
  log "SeaTurtleOS — Image Pre-pull"
  log "Platform: $PLATFORM"
  log "Output: $OUTPUT_DIR"
  echo ""

  check_docker
  build_custom_images
  pull_registry_images
  save_images
  generate_manifest

  echo ""
  log "Done. All images packaged for offline deployment."
  log "Tarball: $OUTPUT_DIR/seaturtle-images.tar.gz"
  log "Manifest: $OUTPUT_DIR/manifest.json"
}

main
