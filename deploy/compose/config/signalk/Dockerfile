FROM signalk/signalk-server:latest

# Install the MQTT gateway plugin into a pre-baked directory.
# At runtime, entrypoint.sh copies these into the mounted volume on first boot.
# This avoids the bind mount masking the baked-in node_modules.
COPY --chown=node:node package.json /home/node/.signalk-prebaked/package.json
USER node
RUN cd /home/node/.signalk-prebaked && npm install --save signalk-mqtt-gw

# Seed plugin configuration
USER root
COPY --chown=node:node plugin-config-data/ /home/node/.signalk-prebaked/plugin-config-data/
COPY --chown=node:node entrypoint.sh /home/node/entrypoint.sh
RUN chmod +x /home/node/entrypoint.sh

USER node
ENTRYPOINT ["/home/node/entrypoint.sh"]
