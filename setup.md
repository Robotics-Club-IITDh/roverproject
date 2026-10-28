# ROS 2 Jazzy + Gazebo + Nav2 Docker Setup

A ready-made development container for the club's ROS 2 work: ROS 2 Jazzy, Gazebo, Nav2 and SLAM Toolbox, with GPU-accelerated Gazebo on NVIDIA machines.

## 1. What you get

- Ubuntu 24.04 with ROS 2 Jazzy (desktop) and Gazebo
- Nav2, Nav2 bringup and SLAM Toolbox pre-installed
- A non-root user called `dev` (with `sudo`), not root
- Workspace folder at `/ros_ws`
- GPU rendering for Gazebo and RViz through your NVIDIA card

## 2. Requirements (NVIDIA machines)

You need all four of these on your **host** (your laptop, not inside the container):

1. An NVIDIA GPU
2. The proprietary NVIDIA driver
3. Docker
4. `nvidia-container-toolkit`, which lets Docker pass the GPU into the container

### 2.1 Check the NVIDIA driver

```bash
nvidia-smi
```

If this prints a table with your GPU, the driver is fine. If it says command not found, install the driver first (on Ubuntu: Software & Updates → Additional Drivers, pick the recommended proprietary driver, then reboot).

### 2.2 Install Docker

Follow the official guide for your OS: https://docs.docker.com/engine/install/ubuntu/

Then let your user run Docker without `sudo`, and log out and back in:

```bash
sudo usermod -aG docker $USER
```

### 2.3 Install nvidia-container-toolkit

```bash
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

If any of these commands fail, the official guide is the source of truth: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html

### 2.4 Verify Docker can see the GPU

```bash
docker run --rm --gpus all ubuntu nvidia-smi
```

You should see the same GPU table as on the host. If you do, the hard part is done.

## 3. Build the image

Put the `Dockerfile` in an empty folder and run, from that folder:

```bash
docker build -t ros-club .
```

The first build takes a while because it downloads ROS, Gazebo and Nav2. You only repeat it when the Dockerfile changes.

## 4. Run the container

Create a folder on your host for your code. Anything you keep in it survives after the container exits:

```bash
mkdir -p ~/ros_ws
```

Allow GUI windows from the container (run once per login):

```bash
xhost +local:docker
```

Start the container:

```bash
docker run -it --rm --net=host --gpus all \
  -e DISPLAY=$DISPLAY \
  -e NVIDIA_DRIVER_CAPABILITIES=all \
  -e __NV_PRIME_RENDER_OFFLOAD=1 \
  -e __GLX_VENDOR_LIBRARY_NAME=nvidia \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v ~/ros_ws:/ros_ws \
  ros-club
```

What the flags do:

- `--gpus all` passes your NVIDIA GPU into the container
- `-e DISPLAY` and the `.X11-unix` mount let Gazebo and RViz windows appear on your screen
- the two `__NV...` / `__GLX...` variables make hybrid-graphics laptops (Intel or AMD plus NVIDIA) render on the NVIDIA card instead of the integrated one
- `-v ~/ros_ws:/ros_ws` links your host folder to the workspace inside the container
- `--rm` deletes the container when you exit, so only files under `/ros_ws` are kept

### Open extra terminals in the same container

ROS work needs several terminals (simulation, teleop, RViz). From a new host terminal:

```bash
docker exec -it $(docker ps -q --filter ancestor=ros-club) bash
```

In every terminal, source ROS before using `ros2` commands (skip this if the Dockerfile already does it for you):

```bash
source /opt/ros/jazzy/setup.bash
```

## 5. Check that everything works

Inside the container, open Gazebo’s built-in demo world:

```bash
gz sim shapes.sdf
```

A window with a few shapes should open. To confirm Gazebo is using your NVIDIA card, run `nvidia-smi` on the host while Gazebo is open. A `gz` process should be listed.

## 6. Working with your own code

- Build inside the project you are working on: `colcon build --symlink-install`
- Then run `source install/setup.bash` from that same folder, in every terminal that uses it.
- If two workspaces contain a package with the same name, the one you source last wins, so source only the workspace you are working on.
- Do not commit `build/`, `install/` or `log/` to git.

## 7. Customizing the Dockerfile

- **Add ROS packages:** add `ros-${ROS_DISTRO}-<package-name>` to the `apt-get install` line.
- **Add Python packages:** add a `RUN pip install --break-system-packages <package>` line.
- **Rebuild after any change:** `docker build -t ros-club .`
- **Do not install things by hand inside a running container.** The container is deleted on exit (`--rm`), so manual installs disappear. If you need it permanently, put it in the Dockerfile.
- **File ownership problems on `~/ros_ws`:** the container user `dev` normally has UID 1000. If your host UID is different, files you create in the container may show up owned by the wrong user. Check yours with `id -u`. If the Dockerfile has a `UID` build argument, rebuild with `--build-arg UID=$(id -u)`.

## 8. No NVIDIA GPU?

This setup is built for NVIDIA. On AMD or Intel-only machines, remove `--gpus all` and the three NVIDIA `-e` flags (`NVIDIA_DRIVER_CAPABILITIES`, `__NV_PRIME_RENDER_OFFLOAD`, `__GLX_VENDOR_LIBRARY_NAME`) from the run command, and add `--device /dev/dri` instead. Everything runs on your integrated graphics or on software rendering. It is slower, and heavy Gazebo worlds may lag.

## 9. Troubleshooting

**Gazebo opens as a black window.** Run `export GZ_IP=127.0.0.1` inside the container, then start Gazebo again.

**`cannot open display` or no window appears.** Run `xhost +local:docker` on the host and check that `-e DISPLAY=$DISPLAY` and the `.X11-unix` mount are in your run command.

**`could not select device driver "" with capabilities: [[gpu]]`** The NVIDIA container toolkit is not set up. Redo section 2.3 and restart Docker.

**`libEGL warning` or `/dev/dri/renderD129: Permission denied` messages in the terminal.** Usually harmless if Gazebo still opens and renders. If it does not render, add `--device /dev/dri` to the run command.

**Gazebo is slow or `nvidia-smi` does not list `gz` while it runs.** It is probably rendering on the integrated GPU. Check that the two `__NV...` / `__GLX...` variables are in your run command.

**Changes to my code disappeared.** You saved it outside `/ros_ws`. Only that folder is kept.

**`ros2: command not found`.** You forgot to source ROS in that terminal: `source /opt/ros/jazzy/setup.bash`.
