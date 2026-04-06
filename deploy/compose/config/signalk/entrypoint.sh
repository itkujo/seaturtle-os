#!/bin/sh
# SeaTurtleOS Signal K entrypoint
# Copies pre-installed plugins from the image into the mounted config volume
# on first boot, then starts Signal K.

SIGNALK_DIR="/home/node/.signalk"
PREBAKED="/home/node/.signalk-prebaked"

# If no package.json in the mounted volume, seed from pre-baked directory
if [ ! -f "$SIGNALK_DIR/package.json" ]; then
  echo "seaturtle-signalk: first boot — seeding plugins from image"
  cp -a "$PREBAKED/package.json" "$SIGNALK_DIR/package.json"
  cp -a "$PREBAKED/node_modules" "$SIGNALK_DIR/node_modules"
  echo "seaturtle-signalk: plugins seeded"
fi

# Seed plugin config if not already present
if [ ! -d "$SIGNALK_DIR/plugin-config-data" ]; then
  echo "seaturtle-signalk: seeding plugin configuration"
  cp -a "$PREBAKED/plugin-config-data" "$SIGNALK_DIR/plugin-config-data"
  echo "seaturtle-signalk: plugin configuration seeded"
fi

exec /home/node/signalk/node_modules/.bin/signalk-server "$@"
