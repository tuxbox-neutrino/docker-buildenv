#!/bin/bash
# Initialize tuxbox-builder container...
echo 'Initialize tuxbox-builder container...'

# Define a dedicated user group
GROUP_NAME="${USER_GROUP:-$USER}"

# Ensure the group exists, create it if necessary
if ! getent group "$GROUP_NAME" > /dev/null; then
    echo "Group $GROUP_NAME does not exist. Creating..."
    groupadd "$GROUP_NAME"
fi

# Ensure the user exists, create it if necessary
if ! id "$USER" &>/dev/null; then
    echo "User $USER does not exist. Creating..."
    useradd -m -s /bin/bash -g "$GROUP_NAME" -G www-data "$USER"
else
    usermod -aG "$GROUP_NAME" "$USER"
    usermod -aG www-data "$USER"
fi

# Prepare global Git configuration
mkdir -p "${XDG_CONFIG_HOME:-$USER_DIR/.config}/git"
echo 'Setting up global Git configuration...'
echo -e "[user]\n\temail = ${GIT_EMAIL}\n\tname = ${GIT_USER}" > "${XDG_CONFIG_HOME}/git/config"
chown -R "$USER":"$GROUP_NAME" "${XDG_CONFIG_HOME}/git"

# Prepare SSH configuration
mkdir -p "${USER_DIR}/.ssh"

# Optimize chown: Only change ownership if incorrect
for dir in "$USER_VOLUME_WORKDIR" "$WWW_DOCDIR"; do
    if [ -d "$dir" ]; then
        current_owner=$(stat -c "%U:%G" "$dir")
        if [ "$current_owner" != "$USER:$GROUP_NAME" ]; then
            echo "Updating ownership for $dir..."
            chown -R "$USER":"$GROUP_NAME" "$dir"
        fi
    fi
done

# Optimize chmod: Only change permissions if incorrect
for dir in "$USER_VOLUME_WORKDIR" "$WWW_DOCDIR"; do
    if [ -d "$dir" ]; then
        if find "$dir" -not -perm -g+rw | grep . > /dev/null 2>&1; then
            echo "Updating permissions for $dir..."
            chmod -R g+rw "$dir"
        fi
    fi
done

echo "User $USER is set up with group $GROUP_NAME and www-data for shared access."

# Prepare build environment
if [ ! -d "${USER_VOLUME_WORKDIR}/${BUILDENV_PREFIX}/.git" ]; then
    if cd "${USER_VOLUME_WORKDIR}"; then
        echo "Cloning build environment repository..."
        git clone "${BUILDENV_GIT_URL}" "${BUILDENV_PREFIX}"
    else
        echo "Error: Could not change directory to ${USER_VOLUME_WORKDIR}" >&2
        exit 1
    fi
else
    echo "Repository [${USER_VOLUME_WORKDIR}/${BUILDENV_PREFIX}] already exists. Not modified!"
fi
chown -R "$USER":"$GROUP_NAME" "$USER_VOLUME_WORKDIR"

# Detect the build environment version
BUILDENV_DISTRO_VERSION=$(grep 'DEFAULT_IMAGE_VERSION=' "${START_PATH}/init.sh" | cut -d'=' -f2 | tr -d '"')
echo "Detected DISTRO_VERSION = $BUILDENV_DISTRO_VERSION within ${START_PATH}"

# Prepare web server content if enabled
if [ "${EXPLORER_ENABLE}" != "false" ]; then

    if [ ! -d "${WWW_DOCDIR}/.git" ]; then
        echo 'Cloning File Explorer web content repository...'
        git clone "${EXPLORER_GIT_URL}" "${WWW_DOCDIR}"
    fi

    # Download default configuration file if it does not exist
    if [ ! -f "${WWW_DOCDIR}/config/config.php" ]; then
        echo "[${WWW_DOCDIR}/config/config.php] does not exist. Downloading..."
        curl -o "${WWW_DOCDIR}/config/config.php" "https://raw.githubusercontent.com/dbt1/support/master/docker-buildenv/config-sample.php"
    else
        echo "Repository [${WWW_DOCDIR}] already exists and configured. Not modified!"
    fi

    # Find the build directory based on detected distro version
    BUILD_DIR=$(find "${START_PATH}" -type d -path "*-${BUILDENV_DISTRO_VERSION}/build" ! -path "*-${BUILDENV_DISTRO_VERSION}/build/*" 2>/dev/null)
    if [ -n "$BUILD_DIR" ]; then
        sed -i "s|#@FILES_DIRECTORY@|\\\$FILES_DIRECTORY = '$BUILD_DIR'|g" "${WWW_DOCDIR}/config/config.php"
    fi

    chown -R "$USER":"$GROUP_NAME" "$WWW_DOCDIR"

else
    echo "EXPLORER_ENABLE is disabled. Skipping web server setup."
fi

# Prepare user profile with environment variables
echo 'Configuring user profile...'
BASH_RC_FILE="${USER_DIR}/.bashrc"
sed -i "s|@START_PATH@|${START_PATH}|g" "$BASH_RC_FILE"
sed -i "s|@BUILDENV_GIT_URL@|${BUILDENV_GIT_URL}|g" "$BASH_RC_FILE"
sed -i "s|@DOCKER_BUILDENV_VERSION@|${DOCKER_BUILDENV_VERSION}|g" "$BASH_RC_FILE"
sed -i "s|@HISTFILE@|${HISTFILE}|g" "$BASH_RC_FILE"
sed -i "s|@LANG@|${LOCALE_LANG}|g" "$BASH_RC_FILE"
sed -i "s|@BUILDENV_VERSION@|${BUILDENV_DISTRO_VERSION}|g" "$BASH_RC_FILE"
sed -i "s|@DOCKER_BUILDENV_GIT_URL@|${DOCKER_BUILDENV_GIT_URL}|g" "$BASH_RC_FILE"
sed -i "s|@LOCAL_HOSTNAME@|${LOCAL_HOSTNAME}|g" "$BASH_RC_FILE"
chown "$USER":"$GROUP_NAME" "$BASH_RC_FILE"

# Mark container as ready
touch /tmp/container_ready
echo "Container setup complete. Ready to start services..."
echo "Enjoy...!"

# Start services using runsvdir
exec runsvdir -P /etc/service
