#!/usr/bin/env bash
# SeaTurtleOS — Load pre-pulled Docker images from tarball.
#
# This runs ONCE on first boot via systemd, then the marker file is
# removed so it never runs again. Images are loaded into Docker's
# local store; the tarball is deleted afterward to reclaim disk space.

set -euo pipefail

IMAGES_TARBALL="/opt/seaturtle/images/seaturtle-images.tar.gz"
LOG_TAG="seaturtle-preload"

log() { echo "$LOG_TAG: $*"; logger -t "$LOG_TAG" "$*" 2>/dev/null || true; }

if [[ ! -f "$IMAGES_TARBALL" ]]; then
  log "No image tarball found at $IMAGES_TARBALL — skipping"
  exit 0
fi

log "Loading Docker images from $IMAGES_TARBALL..."

# docker load reads a tar stream; gunzip feeds it
gunzip -c "$IMAGES_TARBALL" | docker load

log "Docker images loaded successfully."

# Clean up the tarball to free disk space (~1-2 GB)
rm -f "$IMAGES_TARBALL"
log "Tarball removed to free disk space."

# Verify images are available
LOADED=$(docker images --format '{{.Repository}}:{{.Tag}}' | wc -l)
log "Docker now has $LOADED images available."
