#!/bin/bash

# Path to.env-Datei
ENV_FILE=".env"

BUILDENV_VERSION="3.2.4"
TB_VERSION="latest"
TB_BUILD_TIME=$(date '+%Y-%m-%d %H:%M:%S')
USER=$(whoami)
USER_ID=$(id -u)
USER_GROUP_ID=$(id -g)
USER_DIR="${HOME}"
HOST_PREFIX=tuxbox
BUILDENV_PREFIX="buildenv"
LOCAL_HOSTNAME=$(hostname)
ENABLE_UI_TOOLS="false"
USER_VOLUME_BINDIR="${USER_DIR}/bin"
USER_VOLUME_WORKDIR="${USER_DIR}/${HOST_PREFIX}"
USER_VOLUME_WORKBINDIR="${USER_VOLUME_WORKDIR}/bin"
USER_VOLUME_DATADIR="${USER_VOLUME_WORKDIR}/.data"
HISTFILE_NAME=".bash_history"
HISTFILE="${USER_VOLUME_DATADIR}/${HISTFILE_NAME}"

# Set default values for GIT_EMAIL, GIT_USER
GIT_EMAIL="${USER}@${HOSTNAME}"
GIT_USER="$(grep "${USER}" /etc/passwd | cut -d: -f5 | sed 's/,//g')"

# Check if git is installed
if git --version &>/dev/null; then
    # Git is installed, try to get global values
    GLOBAL_EMAIL=$(git config --global user.email)
    if [ -z "$GLOBAL_EMAIL" ]; then
        GLOBAL_EMAIL=$GIT_EMAIL
    fi
    GLOBAL_USER=$(git config --global user.name)
    if [ -z "$GLOBAL_USER" ]; then
        GLOBAL_USER=$GIT_USER
    fi
    
    # Check if inside a Git repository
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        # Try to get local values if globals are not set
        [ -z "$GLOBAL_EMAIL" ] && GIT_EMAIL=$(git config --local user.email) || GIT_EMAIL=$GLOBAL_EMAIL
        [ -z "$GLOBAL_USER" ] && GIT_USER=$(git config --local user.name) || GIT_USER=$GLOBAL_USER

        # Get version info
        last_tag=$(git describe --tags --abbrev=0 2>/dev/null)
        last_commit_id=$(git rev-parse --short HEAD)
        current_branch=$(git rev-parse --abbrev-ref HEAD)
        if [ -z "$last_tag" ]; then
            commit_count=$(git rev-list --count HEAD)
            TB_VERSION="git+${commit_count}-${last_commit_id}-${current_branch}"
        else
            commit_count=$(git rev-list --count ${last_tag}..HEAD)
            TB_VERSION="${last_tag}.${commit_count}-${current_branch}"
        fi
    else
        # Not inside a Git repo, use global values if available
        GIT_EMAIL=${GLOBAL_EMAIL:-$GIT_EMAIL}
        GIT_USER=${GLOBAL_USER:-$GIT_USER}
    fi
else
    echo "Git is not installed, using default values."
fi

# Create environment variables and write into .env
cat <<EOF >$ENV_FILE
BUILDENV_GIT_URL=https://github.com/tuxbox-neutrino/buildenv.git
BUILDENV_VERSION=${BUILDENV_VERSION}
BUILDENV_PREFIX=${BUILDENV_PREFIX}
TB_BUILD_TIME=${TB_BUILD_TIME}
DISPLAY=${DISPLAY}
ENABLE_UI_TOOLS=${ENABLE_UI_TOOLS}
GIT_EMAIL=${GIT_EMAIL}
GIT_USER=${GIT_USER}
HISTFILE=${HISTFILE}
HISTFILE_NAME=${HISTFILE_NAME}
HOST_PREFIX=${HOST_PREFIX}
LANGUAGE=${LANG}
LC_ALL=${LANG}
LOCALE_LANG=${LANG}
LOCAL_HOSTNAME=${LOCAL_HOSTNAME}
NVIDIA_VISIBLE_DEVICES=all
QT_QUICK_BACKEND=software
QT_XCB_GL_INTEGRATION=xcb_egl
START_PATH=${USER_VOLUME_WORKDIR}/${BUILDENV_PREFIX}
TERM=${TERM}
TZ=$(cat /etc/timezone)
USER=${USER}
USER_DIR=${USER_DIR}
USER_GROUP=${USER}
USER_GROUP_ID=${USER_GROUP_ID}
USER_ID=${USER_ID}
USER_PASSWORD=${USER}
USER_VOLUME_WORKDIR=${USER_VOLUME_WORKDIR}
USER_VOLUME_DATADIR=${USER_VOLUME_DATADIR}
USER_VOLUME_BINDIR=${USER_VOLUME_BINDIR}
USER_VOLUME_WORKBINDIR=${USER_VOLUME_WORKBINDIR}
TB_VERSION=${TB_VERSION}
XDG_CONFIG_HOME=/home
XDG_RUNTIME_DIR=/tmp/runtime-root
EOF

# validate
echo ".env-file successfully created with:"
cat $ENV_FILE
