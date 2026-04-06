#!/usr/bin/env bash
# SeaTurtleOS — Build a Raspberry Pi image using rpi-image-gen in Docker.
#
# Usage:
#   ./build-image.sh pi5              # Build Pi 5 SD card image
#   ./build-image.sh pi4              # Build Pi 4 SD card image
#   ./build-image.sh cm5-halpi2       # Build CM5/HalPi2 NVMe image
#   ./build-image.sh --list           # List available device profiles
#   ./build-image.sh --shell          # Drop into builder shell (debug)
#
# Prerequisites:
#   - Docker with buildx
#   - Pre-pulled images in os/device-image/images/ (run pull-images.sh first)
#
# Output: os/device-image/output/<profile>-seaturtle-os.img

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$IMAGE_DIR/../.." && pwd)"
OUTPUT_DIR="$IMAGE_DIR/output"
BUILDER_IMAGE="seaturtle/image-builder:latest"

# ── Parse arguments ──────────────────────────────────────────────
PROFILE=""
SHELL_MODE=false

usage() {
  echo "Usage: $0 <profile|--list|--shell>"
  echo ""
  echo "Profiles:"
  echo "  pi4            Raspberry Pi 4 (SD card)"
  echo "  pi5            Raspberry Pi 5 (SD card)"
  echo "  cm5-halpi2     CM5 / HalPi2 (NVMe SSD)"
  echo ""
  echo "Options:"
  echo "  --list         List available device profiles"
  echo "  --shell        Drop into builder container shell"
  echo "  -h, --help     Show this help"
  exit 0
}

case "${1:-}" in
  pi4|pi5|cm5-halpi2) PROFILE="$1" ;;
  --list)
    echo "Available profiles:"
    for f in "$IMAGE_DIR/config"/*.yaml; do
      basename "$f" .yaml
    done
    exit 0
    ;;
  --shell) SHELL_MODE=true ;;
  -h|--help|"") usage ;;
  *) echo "Unknown profile: $1"; echo "Run $0 --list for available profiles"; exit 1 ;;
esac

# ── Helper functions ─────────────────────────────────────────────
log() { echo "==> $*"; }
err() { echo "ERROR: $*" >&2; exit 1; }

# ── Verify prerequisites ────────────────────────────────────────
command -v docker >/dev/null 2>&1 || err "Docker is not installed"
docker info >/dev/null 2>&1 || err "Docker daemon is not running"

IMAGES_TARBALL="$IMAGE_DIR/images/seaturtle-images.tar.gz"
if [[ ! -f "$IMAGES_TARBALL" ]] && [[ "$SHELL_MODE" == "false" ]]; then
  err "Pre-pulled images not found at $IMAGES_TARBALL. Run pull-images.sh first."
fi

# ── Build builder image if needed ────────────────────────────────
if ! docker image inspect "$BUILDER_IMAGE" >/dev/null 2>&1; then
  log "Building builder image (first time only)..."
  docker build -t "$BUILDER_IMAGE" "$IMAGE_DIR/builder"
fi

# ── Prepare output directory ─────────────────────────────────────
mkdir -p "$OUTPUT_DIR"

# ── Run builder ──────────────────────────────────────────────────
DOCKER_ARGS=(
  --rm
  --privileged
  -v "$IMAGE_DIR/config:/build/config:ro"
  -v "$IMAGE_DIR/layers:/build/layers:ro"
  -v "$IMAGE_DIR/images:/build/images:ro"
  -v "$OUTPUT_DIR:/build/output"
)

if [[ "$SHELL_MODE" == "true" ]]; then
  log "Dropping into builder shell..."
  log "  Config: /build/config/"
  log "  Layers: /build/layers/"
  log "  Images: /build/images/"
  log "  Output: /build/output/"
  docker run -it "${DOCKER_ARGS[@]}" "$BUILDER_IMAGE" bash
  exit 0
fi

CONFIG_FILE="/build/config/$PROFILE.yaml"
log "SeaTurtleOS Image Build"
log "Profile: $PROFILE"
log "Config:  $CONFIG_FILE"
log "Output:  $OUTPUT_DIR/"
echo ""

docker run "${DOCKER_ARGS[@]}" "$BUILDER_IMAGE" bash -c "
  set -euo pipefail

  echo '==> Copying config and layers into rpi-image-gen structure...'

  # Link our custom layers into rpi-image-gen's layer directory
  for layer_dir in /build/layers/*/; do
    layer_name=\$(basename \"\$layer_dir\")
    ln -sfn \"\$layer_dir\" \"/opt/rpi-image-gen/layer/\$layer_name\"
    echo \"  Linked layer: \$layer_name\"
  done

  echo '==> Starting rpi-image-gen build...'
  cd /opt/rpi-image-gen

  # Run the build with our config
  ./rpi-image-gen build -c \"$CONFIG_FILE\"

  echo '==> Copying output image...'
  cp -v /opt/rpi-image-gen/work/*/\*.img /build/output/ 2>/dev/null || \
    echo 'WARNING: No .img file found in work directory. Check build logs.'

  echo '==> Build complete.'
"

log "Done. Image saved to $OUTPUT_DIR/"
ls -lh "$OUTPUT_DIR/"*.img 2>/dev/null || log "No .img files in output directory"
