# HatLabs HalPi2 Hardware Profile

## Overview

The HalPi2 is a CM5-based marine computer from HatLabs, designed specifically
for running Signal K and related marine software on boats.

**Product**: HalPi2 (CM5 variant)
**Manufacturer**: HatLabs
**Price**: ~$688 (16GB RAM / 1TB SSD configuration)
**Website**: https://hatlabs.fi/

## Specifications

| Component | Specification |
|-----------|--------------|
| **Compute** | Raspberry Pi CM5, 16 GB RAM |
| **Storage** | 1 TB NVMe SSD |
| **Power Input** | 10-32V DC (covers 12V and 24V boat systems) |
| **Power Supply** | Built-in with short-term energy storage (survives engine cranking / voltage spikes) |
| **Shutdown** | Integrated RP2040 microcontroller for graceful shutdown on power loss |
| **NMEA 2000** | Micro-C connector (direct CAN bus connection) |
| **NMEA 0183** | Isolated serial interface |
| **CAN Bus** | Integrated controller |
| **Enclosure** | IP65 die-cast aluminium, 200 x 130 x 60 mm |
| **Networking** | Ethernet, Wi-Fi (from CM5) |

## Key Features for SeaTurtleOS

- **Power resilience**: The built-in energy storage and RP2040 graceful-shutdown
  controller are critical for marine environments where power is unreliable.
  The RP2040 detects power loss and signals the CM5 to shut down cleanly before
  energy reserves are depleted.

- **Direct NMEA 2000**: The Micro-C connector means no USB-to-CAN adapter is needed.
  Signal K can read the CAN bus directly via `socketcan`.

- **IP65 enclosure**: Suitable for installation in engine rooms, electrical panels,
  and other harsh marine environments.

- **Ships with Halos + Signal K**: The HalPi2 comes pre-configured with HatLabs'
  Halos operating system and Signal K. SeaTurtleOS would replace the OS image.

## SeaTurtleOS Compatibility

- **Device layer**: `device/cm5/` in rpi-image-gen (Compute Module 5)
- **Storage**: NVMe SSD — use `storage_type: nvme` in image config
- **Docker**: 16 GB RAM is more than sufficient for the full service stack
- **Networking**: Both Ethernet and Wi-Fi available for vessel network access

## Development Note

The primary development target is standard Raspberry Pi 4/5 hardware.
The HalPi2 is a production deployment target. Signal K runs with simulated
data during macOS development (no NMEA hardware available).
