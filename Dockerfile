# syntax=docker/dockerfile:1.6

# Jetson/ARM64 ROS Humble desktop base
FROM --platform=linux/arm64 ghcr.io/sloretz/ros:humble-desktop

ENV DEBIAN_FRONTEND=noninteractive

# Base tools + ROS build helpers + video utils + GStreamer + USB libs
RUN apt-get update && apt-get install -y --no-install-recommends \
    usbutils libusb-1.0-0  \
    git curl wget ca-certificates gpg gnupg lsb-release \
    python3-pip python3-vcstool python3-colcon-common-extensions python3-rosdep \
    v4l-utils udev usbutils libusb-1.0-0 \
    gstreamer1.0-tools libgstreamer1.0-0 \
    gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly \
 && rm -rf /var/lib/apt/lists/*


# ============================================================
# =============  VIZIONSDK OFFLINE / VERSIONE FISSA ==========
# ============================================================

# Copio i pacchetti locali (cartella third_party nel build context)
COPY third_party/vizionsdk-linuxarm64-25.12.1.deb /tmp/
COPY third_party/pyvizionsdk-25.12.1-cp310-cp310-manylinux_2_31_aarch64.whl /tmp/

# Installa vizionsdk da .deb (senza vizionviewer)
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        /tmp/vizionsdk-linuxarm64-25.12.1.deb; \
    rm -rf /var/lib/apt/lists/*

# pyvizionsdk + requests + watchdog (versione fissata da .whl)
RUN pip3 install --no-cache-dir \
        /tmp/pyvizionsdk-25.12.1-cp310-cp310-manylinux_2_31_aarch64.whl \
 && pip3 install --no-cache-dir \
        requests \
        watchdog \
 && rm -f /tmp/pyvizionsdk-25.12.1-cp310-cp310-manylinux_2_31_aarch64.whl


# ============================================================
# ==================  UTENTE ROS / DEV  ======================
# ============================================================

# Create mount points used at runtime (they'll be bind-mounted)
ARG USERNAME=dev
RUN mkdir -p /home/${USERNAME}/ws /home/${USERNAME}/bags
RUN useradd -m -s /bin/bash ${USERNAME} \
 && groupadd -f video \
 && groupadd -f plugdev \
 && groupadd -f i2c \
 && usermod -aG video,plugdev,i2c ${USERNAME}

# rosdep: init as root, then update as the target user
RUN rosdep init || true
RUN mkdir -p /home/${USERNAME}/.ros && chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}

USER ${USERNAME}
RUN rosdep update

# Auto-source ROS + overlay when present
RUN echo "source /opt/ros/humble/setup.bash" >> /home/${USERNAME}/.bashrc \
 && echo "[ -f ~/ws/install/setup.bash ] && source ~/ws/install/setup.bash" >> /home/${USERNAME}/.bashrc

# GStreamer defaults inside container
ENV GST_PLUGIN_PATH=/usr/lib/aarch64-linux-gnu/gstreamer-1.0
ENV GST_PLUGIN_SCANNER=/usr/lib/aarch64-linux-gnu/gstreamer-1.0/gst-plugin-scanner

WORKDIR /home/${USERNAME}/ws
CMD ["/bin/bash"]

