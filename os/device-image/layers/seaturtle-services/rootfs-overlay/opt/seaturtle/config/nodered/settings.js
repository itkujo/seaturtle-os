/**
 * SeaTurtleOS — Node-RED Settings
 * Docs: https://nodered.org/docs/user-guide/runtime/configuration
 *
 * This file is mounted read-only into the container.
 * Flow files and credentials are stored in /data (bind-mounted to ./data/nodered).
 */
const bcrypt = require("bcryptjs");

module.exports = {
  // Flow file storage
  flowFile: "flows.json",
  flowFilePretty: true,

  // Credential encryption key — sourced from environment variable
  // set in compose.base.yaml via SEATURTLE_INITIAL_PASSWORD.
  credentialSecret: process.env.NODE_RED_CREDENTIAL_SECRET || "changeseaturtle",

  // User directory for flows, nodes, and credentials
  userDir: "/data",

  // ── Authentication ──────────────────────────────────────────────
  // Password hash computed at startup from SEATURTLE_INITIAL_PASSWORD.
  // No manual bcrypt generation required — zero-touch operation.
  adminAuth: {
    type: "credentials",
    users: [
      {
        username: "admin",
        password: bcrypt.hashSync(
          process.env.NODE_RED_CREDENTIAL_SECRET || "changeseaturtle",
          8
        ),
        permissions: "*",
      },
    ],
  },

  // Logging
  logging: {
    console: {
      level: "info",
      metrics: false,
      audit: false,
    },
  },

  // Editor settings
  editorTheme: {
    projects: {
      enabled: false,
    },
    tours: false,
  },

  // Function node external modules (allow npm packages in function nodes)
  functionExternalModules: true,

  // MQTT broker default — points at the Mosquitto container on the seaturtle network
  mqttReconnectTime: 15000,

  // Disable palette manager in production to prevent accidental installs.
  // Set to true during development if you need to install nodes via the GUI.
  // externalModules: {
  //   palette: {
  //     allowInstall: false,
  //   },
  // },
};
