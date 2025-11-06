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

# --- TechNexion repos: vizionsdk + vizionviewer ---
RUN set -eux; \
    mkdir -p /etc/apt/keyrings; \
    wget -qO- https://download.technexion.com/apt/technexion.asc | gpg --dearmor > /tmp/packages.technexion.gpg; \
    install -D -o root -g root -m 644 /tmp/packages.technexion.gpg /etc/apt/keyrings/packages.technexion.gpg; \
    echo 'deb [arch=arm64 signed-by=/etc/apt/keyrings/packages.technexion.gpg] https://download.technexion.com/apt/vizionsdk/ stable main' > /etc/apt/sources.list.d/vizionsdk.list; \
    echo 'deb [arch=arm64 signed-by=/etc/apt/keyrings/packages.technexion.gpg] https://download.technexion.com/apt/vizionviewer/ stable main' >> /etc/apt/sources.list.d/vizionsdk.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends vizionsdk vizionviewer; \
    rm -rf /var/lib/apt/lists/* /tmp/packages.technexion.gpg

# pyvizionsdk + requests + watchdog
RUN pip3 install --no-cache-dir \
    --extra-index-url https://pypi.vizionsdk.com/root/pyvizionsdk/+simple/ \
    pyvizionsdk \
 && pip3 install --no-cache-dir requests watchdog

# Create mount points used at runtime (they'll be bind-mounted)
# Normal user with video + plugdev + i2c access
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



