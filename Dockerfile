FROM osrf/ros:jazzy-desktop-noble

SHELL ["/bin/bash", "-c"]

RUN apt-get update && apt-get install -y \
    ros-jazzy-ros-gz \
    mesa-utils x11-apps libglvnd0 libegl1 libgl1 \
    sudo git vim nano python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Non-root user matching your host user, with sudo
ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=1000
RUN (userdel -r ubuntu 2>/dev/null || true) \
    && groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m -s /bin/bash $USERNAME \
    && usermod -aG video $USERNAME \
    && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

ENV GZ_IP=127.0.0.1 \
    QT_QPA_PLATFORM=xcb \
    QT_X11_NO_MITSHM=1 \
    XDG_RUNTIME_DIR=/tmp/runtime-dev \
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=all \
    __NV_PRIME_RENDER_OFFLOAD=1 \
    __GLX_VENDOR_LIBRARY_NAME=nvidia

RUN mkdir -p /ros_ws /tmp/runtime-dev \
    && chown $USERNAME:$USERNAME /ros_ws /tmp/runtime-dev \
    && chmod 700 /tmp/runtime-dev \
    && echo "source /opt/ros/jazzy/setup.bash" >> /home/$USERNAME/.bashrc

# Add new packages below this line
RUN apt-get update && apt-get install -y \
    ros-jazzy-teleop-twist-keyboard \
    ros-jazzy-navigation2 \
    ros-jazzy-nav2-bringup \
    "ros-jazzy-nav2-minimal-tb*" \
    ros-jazzy-slam-toolbox \
    && rm -rf /var/lib/apt/lists/*

USER $USERNAME
WORKDIR /ros_ws
CMD ["bash"]
