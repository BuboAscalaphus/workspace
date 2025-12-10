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
# ==============  INSTALLAZIONE OFFLINE VIZIONSDK  ===========
# ============================================================

# Copia i pacchetti .deb e il wheel locali
COPY third_party/vizionsdk-linuxarm64.deb /tmp/
COPY third_party/vizionviewer-linuxarm64.deb /tmp/
COPY third_party/pyvizionsdk-25.10.3-cp310-cp310-manylinux_2_31_aarch64.whl /tmp/

# Installa vizionsdk + vizionviewer da .deb (versioni fissate)
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        /tmp/vizionsdk-linuxarm64.deb \
        /tmp/vizionviewer-linuxarm64.deb; \
    rm -rf /var/lib/apt/lists/*


# Installa pyvizionsdk versione fissa dal wheel scaricato
RUN pip3 install --no-cache-dir \
        /tmp/pyvizionsdk-25.10.3-cp310-cp310-manylinux_2_31_aarch64.whl \
 && pip3 install --no-cache-dir requests watchdog \
 && rm -f /tmp/pyvizionsdk-25.10.3-cp310-cp310-manylinux_2_31_aarch64.whl


# ============================================================
# ================  CREAZIONE UTENTE DEV  ====================
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
# ==============  INSTALLAZIONE OFFLINE VIZIONSDK  ===========
# ============================================================

# Copia i pacchetti .deb e il wheel locali
COPY third_party/vizionsdk-linuxarm64-25.10.3.deb /tmp/
COPY third_party/pyvizionsdk-25.10.3-cp310-cp310-manylinux_2_31_aarch64.whl /tmp/

# Installa vizionsdk da .deb (versioni fissate)
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        /tmp/vizionsdk-linuxarm64-25.10.3.deb \
    rm -rf /var/lib/apt/lists/*


# Installa pyvizionsdk versione fissa dal wheel scaricato
RUN pip3 install --no-cache-dir \
        /tmp/pyvizionsdk-25.10.3-cp310-cp310-manylinux_2_31_aarch64.whl \
 && pip3 install --no-cache-dir requests watchdog \
 && rm -f /tmp/pyvizionsdk-25.10.3-cp310-cp310-manylinux_2_31_aarch64.whl


# ============================================================
# ================  CREAZIONE UTENTE DEV  ====================
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

