# SeaTurtleOS — rpi-image-gen build environment
#
# Runs on macOS (Apple Silicon) or Linux. Builds Raspberry Pi images
# using the official rpi-image-gen tool inside a Debian Bookworm container.
#
# Build:  docker build -t seaturtle/image-builder:latest .
# Usage:  See os/device-image/scripts/build-image.sh

FROM debian:bookworm

ARG RPI_IMAGE_GEN_VERSION=v2.4.0
ARG DEBIAN_FRONTEND=noninteractive

# ── System dependencies ──────────────────────────────────────────
# Based on rpi-image-gen/depends file. Installs everything needed
# for mmdebstrap, genimage, and the full build pipeline.
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Build essentials
    build-essential \
    autoconf \
    automake \
    flex \
    gettext \
    libtool \
    pkg-config \
    cmake \
    # Image generation
    dosfstools \
    e2fsprogs \
    btrfs-progs \
    cryptsetup \
    fdisk \
    mtools \
    # Filesystem / chroot
    mmdebstrap \
    podman \
    uidmap \
    dbus-user-session \
    # Python (config parsing)
    python3 \
    python3-yaml \
    python3-debian \
    # Archive / compression
    xz-utils \
    zstd \
    gzip \
    bzip2 \
    cpio \
    # Networking / download
    curl \
    wget \
    ca-certificates \
    gnupg \
    # Utilities
    git \
    rsync \
    dpkg-dev \
    squashfs-tools \
    sudo \
    jq \
    && rm -rf /var/lib/apt/lists/*

# ── Raspberry Pi GPG key ─────────────────────────────────────────
# Required for apt to verify packages from the Raspberry Pi repository
# during image builds.
RUN curl -fsSL https://archive.raspberrypi.com/debian/raspberrypi.gpg.key \
    | gpg --dearmor -o /usr/share/keyrings/raspberrypi-archive-keyring.gpg

# ── Clone rpi-image-gen ──────────────────────────────────────────
RUN git clone --depth 1 --branch "$RPI_IMAGE_GEN_VERSION" \
    https://github.com/raspberrypi/rpi-image-gen.git /opt/rpi-image-gen

# ── Install rpi-image-gen's own dependencies ─────────────────────
# install_deps.sh builds genimage from source and sets up podman storage.
RUN cd /opt/rpi-image-gen && bash install_deps.sh

# ── Create non-root build user ───────────────────────────────────
# rpi-image-gen uses podman unshare / user namespaces and should NOT
# run as root. The user needs passwordless sudo for a few operations.
RUN useradd -m -s /bin/bash imagegen \
    && echo "imagegen ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/imagegen

# ── Configure podman for rootless operation ──────────────────────
RUN mkdir -p /home/imagegen/.config/containers \
    && echo '[storage]' > /home/imagegen/.config/containers/storage.conf \
    && echo 'driver = "overlay"' >> /home/imagegen/.config/containers/storage.conf \
    && chown -R imagegen:imagegen /home/imagegen/.config

# ── Working directory ────────────────────────────────────────────
WORKDIR /build
RUN chown imagegen:imagegen /build

USER imagegen

CMD ["bash"]
