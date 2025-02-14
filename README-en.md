<!-- LANGUAGE_LINKS_START -->
[🇩🇪 German](README-de.md) | <span style="color: grey;">🇬🇧 English</span>
<!-- LANGUAGE_LINKS_END -->

# Docker Build Environment

This repository contains the necessary files to configure, build, and run a Docker container, including `docker-compose.yaml`, `Dockerfile`, and scripts. Some environment variables are stored in a `.env` file, which must be created using the `create-env.sh` script to adopt specific settings from the host system. A base Docker image is automatically downloaded from Docker Hub.

The purpose of this repository is to assist in creating Docker containers that provide the necessary prerequisites for building Neutrino flash images and packages using the Yocto/OE build system.

## Contents
- [Contents](#contents)
- [🚀 Quick Start](#-quick-start)
  - [Build Container](#build-container)
  - [Login to Container](#login-to-container)
  - [Initialize Build Environment in Docker Terminal](#initialize-build-environment-in-docker-terminal)
- [1. Prerequisites](#1-prerequisites)
- [2. Preparation](#2-preparation)
  - [2.1 Clone Repository and Change Directory](#21-clone-repository-and-change-directory)
  - [2.2 Configure Environment Variables](#22-configure-environment-variables)
  - [2.3 Volumes](#23-volumes)
  - [2.4 Configure Ports](#24-configure-ports)
    - [2.4.1 Web Access](#241-web-access)
    - [2.4.2 SSH](#242-ssh)
- [3. Build Container](#3-build-container)
  - [3.1 Example 1](#31-example-1)
- [4. Start Container](#4-start-container)
- [5. Stop Container](#5-stop-container)
- [6. Using the Container](#6-using-the-container)
  - [6.1 Login](#61-login)
  - [6.2 Using the Build Environment](#62-using-the-build-environment)
- [7. Update Container](#7-update-container)
- [8. Support](#8-support)

## 🚀 Quick Start

If you want to quickly get the container running, execute the following steps in a terminal. This assumes that Docker and Docker Compose are already installed.

### Build Container

```bash
~/docker-buildenv $ git clone https://github.com/tuxbox-neutrino/docker-buildenv.git && cd docker-buildenv
                  ./docker-compose build
                  docker-compose up -d
```

### Login to Container

```bash
~/docker-buildenv $ docker exec -it --user $USER tuxbox-build bash
```

### Initialize Build Environment in Docker Terminal

```bash
user@asjghd76dfwh:~/tuxbox/buildenv$ ./init && cd poky-3.2.4
...
Create configurations ...
...
Start build
------------------------------------------------------------------------------------------------
Now you are ready to build your own images and packages.
Selectable machines are:

        hd51 ax51 mutant51 bre2ze4k hd60 ax60 hd61 ax61 h7 zgemmah7 osmio4k osmio4kplus e4hdultra

Select your favorite machine (or identical) and the next steps are:

        cd /home/tg/tuxbox/buildenv/poky-3.2.4 && . ./oe-init-build-env build/<machine>
        bitbake neutrino-image

For more information and next steps, take a look at the README.md!
user@asjghd76dfwh:~/tuxbox/buildenv/poky-3.2.4$
```

No further adjustments should be necessary. After these steps, the container runs in the background and provides the Yocto/OE build environment.
You can now start the build process.

**Note:** Further information on next steps can be found [here](https://github.com/tuxbox-neutrino/buildenv/blob/master/README.md).

## 1. Prerequisites

Tested on Linux Debian 11.x, Ubuntu 20.04, 22.04. It should work on any current distribution where Docker is supported.

Required:
   - Docker, [Installation](https://docs.docker.com/engine/install/debian/#install-using-the-convenience-script)
   - Docker Compose >= v2.24.3, [Installation](https://docs.docker.com/compose/install/standalone/)
   - Git, installable via the package manager according to your distribution

Optional:
   - [Docker Desktop](https://www.docker.com/products/docker-desktop/)
   - Portainer, [Installation](https://docs.portainer.io/start/install-ce/server/docker/linux) (available as a plugin with Docker Desktop)

**Important!** After installing Docker, if you want to run Docker as a non-root user, add yourself to the `docker` group:

```bash
sudo usermod -aG docker $USER
```

Then log out and back in or restart your system for the changes to take effect.

## 2. Preparation

### 2.1 Clone Repository and Change Directory

```bash
git clone https://github.com/tuxbox-neutrino/docker-buildenv.git && cd docker-buildenv
```

### 2.2 Configure Environment Variables

If no `.env` file exists, create one using the provided script. This script retrieves environment variables from the host system and integrates them into the `.env` file.

```bash
./create-env.sh
```

You can rerun this script if needed.

### 2.3 Volumes

The container uses Docker volumes to store persistent data. Default configurations should suffice, but changes can be made in `docker-compose.yml` if necessary.

### 2.4 Configure Ports

#### 2.4.1 Web Access

The container maps port 80 (container) to port 8080 (host) for web access:

- Port: 8080 (Host) -> 80 (Container)

#### 2.4.2 SSH

The container runs an SSH server with the following default settings:

- Port: 222 (Host) -> 22 (Container)
- Password: = Username (as set in `.env` file)

## 3. Build Container

### 3.1 Example 1

Run the Docker Compose wrapper script:

```bash
./docker-compose build
```

## 4. Start Container

```bash
docker-compose up -d
```

## 5. Stop Container

```bash
docker-compose down
```

## 6. Using the Container

### 6.1 Login

To log in, use the container ID or name:

```bash
docker exec -it --user $USER tuxbox-build bash
```

### 6.2 Using the Build Environment

Once logged in, navigate to `buildenv` and update it if necessary:

```bash
git pull -r origin master
```

Proceed as described in the [README.md](https://github.com/tuxbox-neutrino/buildenv/blob/master/README.md).

## 7. Update Container

To update the repository and rebuild the container:

```bash
git pull -r origin master
```

## 8. Support

For issues or support, open an [issue on GitHub](https://github.com/dbt1/docker-buildenv/issues) or visit the [forum](https://forum.tuxbox-neutrino.org/forum/viewforum.php?f=77).

