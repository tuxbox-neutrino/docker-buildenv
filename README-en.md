Note: This is an automatically translated file. Original content from [here](https://github.com/dbt1/docker-tuxbox-build/blob/master/README-de.md):

This repository contains the necessary files to configure, build, and launch a Docker container, including `docker-compose.yaml`, `Dockerfile`, and scripts. Some environment variables are stored in a `.env` file, which must be created with the `create-env.sh` script so that some settings can be adopted by the host system. You also need a base Docker image that is automatically requested from Docker Hub.
The use of this repository is intended to help create Docker containers that provide the necessary requirements to be able to build flash images and packages with the Yocto/OE build system.

- [1. Requirements](#1-requirements)
- [2. Prepare](#2-prepare)
  - [2.1. Clone repository and switch to the cloned repo](#21-repository-clone-and-switch-to-the-cloned-repo)
  - [2.2. Configure environment variables](#22-configure-environment-variables)
  - [2.3 Volumes](#23-volumes)
  - [2.4 Configure Ports](#24-ports-configure)
    - [2.4.1 Web Access](#241-web access)
    - [2.4.2 SSH](#242-ssh)
- [3. Build Container](#3-container-build)
  - [3.1 Example 1](#31-example-1)
  - [3.2 Example 2](#32-example-2)
- [4. Start container](#4-start-container)
- [5. stop container](#5-container-stop)
- [6. Using the Container](#6-using-the-container)
- [6.1. Login](#61-login)
- [6.2. Use build environment](#62-build-environment-use)
- [7. Update Container](#7-update-container)
- [8th. Support](#8-support)

## 1. Requirements

  Tested under Linux Debian 11.x, Ubuntu 20.04, 22.04. But it should work on any current distribution that runs Docker.

  Necessary:
     
   - Docker, [Installation](https://docs.docker.com/engine/install/debian/#install-using-the-convenience-script)
   - Docker Compose >= v2.24.3, [Installation](https://docs.docker.com/compose/install/standalone/)
   - Git, installation via the package manager depending on the distribution
   
  Optional:
   
   - [Docker Desktop](https://www.docker.com/products/docker-desktop/)
   - Portainer, [Installation](https://docs.portainer.io/start/install-ce/server/docker/linux) (available with Docker desktop as a plugin)

  **Important!** After you have installed Docker and want to run Docker as a non-root user, which is appropriate for our purposes, you should add yourself as a user to the "docker" group using this command:

   ```bash
   sudo usermod -aG docker $USER
   ```
  Then to apply the setting, either log out and log in again or restart!

## 2. Prepare

### 2.1. Clone repository and switch to the cloned repo

   ```bash
   git clone https://github.com/dbt1/docker-tuxbox-build.git && cd docker-tuxbox-build
   ```

### 2.2. Configure environment variables

   Run this script to create the necessary `.env` file:

   ```bash
   ./create-env.sh
   ```
   
  The script gets some environment variables from the host system and puts them into an `.env` file so that the container is configured to suit your host system. If this does not cover your requirements, you can adapt this generated `.env` file. However, you should not run the script again, otherwise the `.env` file will be overwritten again. It is therefore advisable to either rename this customized `.env` file and rename it accordingly in the `docker-compose.yml` file, or preferably to use another one in this form as a parameter when running `docker-compose` - -env-file <my .env file>` passed to `docker-compose`.

### 2.3 Volumes

  The container uses Docker Volumes to store persistent data, which allows access to specific files and directories permanently in the container.
  In the standard configuration, these volumes are in principle integrated to suit the environment of your host system and mounted when the container is started, so that ideally you do not have to change anything in the volume configuration.
  If you want to make changes to this, you can find the configuration of the volumes in the `docker-compose.yml`. **Note** that these settings are normally aligned with the paths as preconfigured for the Yocto/OE build environment using the init script from the Buildenv repository. If adjustments are made to this, you should take this into account!
  
  These paths are mounted as volumes in the container. You have normal access to it via your host:

  ```bash
  /home
    └──<$USER>
        ├── tuxbox
        │ ├── .config
        │ ├── .data
        │ ├── am
        │ └── buildenv
        ├── Archives
        ├── am
        ├── sstate cache
  ```

### 2.4 Configure ports

  The container provides some access via certain network ports. This allows access to the build results via a web browser and access to the container via ssh.

#### 2.4.1 Web access

  By default, the container is configured to listen on port 80. Your host is mapped to the container's built-in web server (`lighttpd`) via port 8080:

  - Port: 8080 (host) -> 80 (container)

  This enables access via web server to the generated images and packages (ipk's). Set-top boxes can therefore access updates directly from your home network, for example. If port 8080 on your host system is already in use, you can either adjust these settings in the `docker-compose.yml` file or specify them when starting the container. This could look like this if you map to port 8081:

  - 808**1**:80
   
  Settings on the web server can be made in the responsible lightttpd configuration file, which is available in the corresponding volume:

  ```bash
   ~/tuxbox
     └──.config
        └── lighttpd
            └── lighttpd.conf
  ```
  `dir-listing` is activated in `lighttpd.conf`, so that you can get by without additional content.
  
  ```bash
  ~/tuxbox/config/lighttpd$ cat lighttpd.conf
  ...
  #server.compat-module-load = "disable"
  server.modules += (
        "mod_dirlisting",
        "mod_staticfile",
  )
  dir-listing.activate = "enable"
 ```
 
#### 2.4.2 SSH

  Usually you access the container directly via `docker exec`.
  Since Git is already part of the container, an ssh server is also provided. By default, the ssh server is configured like this:

   - Port: 222 (host) -> 22 (container)
   - Password: = Username (as set in .env)

  If port 222 is already occupied on your host system, you can adjust these settings in the `docker-compose.yml` file, just like with the web server, or specify them when starting the container.
   
  Login from the host system itself:
    
  ```bash
  ssh $USER@localhost -p 222
  ```
  
  Log in from another computer:
    
  ```bash
  ssh <user>@<IP or hostname of the computer on which the container is running> -p 222
  ```
    
## 3. Build containers

### 3.1 Example 1
 
  Run docker-compose wrapper:

   **Note:** The preceding `./` is important here because it is a wrapper script that is in the repo and calls the real `docker-compose`, but beforehand it automatically creates a `.env` file like described in [Step 2.2](#22-configure-environment-variables)! This wrapper script takes all parameters relevant to `docker-compose`. This means that, for example, an alternative `.env file` can be used. This is simply intended to reduce the effort involved in entering commands.

   ```bash
   ./docker-compose build
   ```

### 3.2 Example 2

  Run docker-compose: with different `.env file`

  **Note:** there is an `.env.sample` included in the repository as an example. However, if desired, this must be adjusted and explicitly passed to `docker-compose` when creating the container.

  ```bash
  docker-compose --env-file <path to other .env file> build
  ```

## 4. Start container

   ```bash
   docker-compose up -d
   ```

## 5. Stop containers

   ```bash
   docker-compose down
   ```

## 6. Using the container

## 6.1. log in

   You should know the name or container ID to log in. Run `docker ps` to see which containers are currently available:

   ```bash
   docker ps
   CONTAINER ID IMAGE COMMAND CREATED STATUS PORTS NAMES
   9d6e0d280a9e tuxbox-build:latest "/usr/local/bin/star…" 41 minutes ago Up 41 minutes 0.0.0.0:8080->80/tcp tuxbox-build
   ```

   For example, log in to the container with the `Container ID` **9d6e0d280a9e** or the `Container Name` like this:


   ```bash
   docker exec -it --user $USER tuxbox-build bash
   ```
   or:

   ```bash
   docker exec -it --user $USER <CONTAINER ID> bash
   ```

   You should see something like this prompt:

   ```bash
   ~/tuxbox/buildenv$
   ```

  First you should make sure that the init script is up to date. Therefore, carry out an update:

  ```bash
  ~/tuxbox/buildenv$ git pull -r origin master
  ```

  From now on you can work with the container.

## 6.2. Use build environment

  After logging into the container, you are already in the directory in which the init script is located. Now you can continue as described [here](https://github.com/tuxbox-neutrino/buildenv/blob/master/README.md).

  The images and packages produced by the build system are made available via persistent volumes within your host home directory. By default, this location is intended for this:

  ```bash
  /home
   └──<$USER>
       ├── tuxbox
       : ├── buildenv
           : ├── dist
               :
   ```
  **Note:** If you have set up your volumes differently, this may of course differ.

  The container provides a web server and can be accessed locally and on the LAN via port 8080 by default:

   - [http://localhost<:PORT NUMBER>](http://localhost:8080)
   - [http://127.0.0.1<:PORT NUMBER>](http://127.0.0.1:8080)
   
   or on the LAN

   - [http://IP<:PORT NUMBER>](http://192.168.1.36:8080)


## 7. Update containers

  As stated in [Step 2.1](#21-clone-repository-and-switch-to-the-cloned-repo), the repository that contains the recipe for the container can be updated regularly.
  To do this, go to the repository and run this command:

 ```bash
  ~/docker-tuxbox-build$ git pull -r origin master
 ```

 Then have the container rebuilt as described [here](#3-container-building).

 **NOTE!**: It is not recommended to use Watchtower together with Portainer, as this is a stack that is tailored to your system and the Docker image is created individually and does not (yet) have a container registry such as Docker Hub is available!

## 8. Support

  For further questions or support, open an [Issue in GitHub](https://github.com/dbt1/docker-tuxbox-build/issues) or report in the [Forum](https://forum.tuxbox-neutrino.org /forum/viewforum.php?f=77).