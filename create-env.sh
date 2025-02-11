#!/usr/bin/env bash
#
# create_env.sh - Automatically create the .env file for Docker Compose
# Creates a .env file with user and system settings.
# If a .env file already exists, the user is asked
# if a backup should be created and the file overwritten.

set -e  # Stop on error

# Prints an error message and exits
function error_exit {
    echo "$1" >&2
    exit 1
}

# ------------------------------------------------------------------------------
# Global constants
# ------------------------------------------------------------------------------
ENV_FILE=".env"
BACKUP_DIR="env_backups"
EXIT_USER_CANCEL=70

# ------------------------------------------------------------------------------
# Prompt functions
# ------------------------------------------------------------------------------

# Prompt the user with a message and default value
function prompt {
    local PROMPT_MESSAGE=$1
    local DEFAULT_VALUE=$2
    local PAD_WIDTH=${3:-20}

    # Build the prompt with color logic
    local PROMPT_WITH_COLOR
    PROMPT_WITH_COLOR=$(prompt_color "$PROMPT_MESSAGE" "$DEFAULT_VALUE" "$PAD_WIDTH")

    # Read user input and use default if empty
    read -p "$(echo -e "$PROMPT_WITH_COLOR")" INPUT
    INPUT="${INPUT:-$DEFAULT_VALUE}"

    echo "$INPUT"
}

# Return a color-coded prompt based on whether the current default deviates from the original default
function prompt_color {
    local PROMPT_MESSAGE=$1
    local DEFAULT_VALUE=$2
    local PAD_WIDTH=${3:-20}

    local GREEN="\033[0;32m"
    local YELLOW="\033[0;33m"
    local RESET="\033[0m"

    # Retrieve the original value from a variable named ORIG_<PROMPT_MESSAGE>
    local ORIG_VAR="ORIG_${PROMPT_MESSAGE}"
    local ORIG_VALUE="${!ORIG_VAR}"

    local COLOR="$GREEN"
    if [[ -n "$ORIG_VALUE" && "$DEFAULT_VALUE" != "$ORIG_VALUE" ]]; then
        COLOR="$YELLOW"
    fi

    local ADJUSTED_WIDTH=$((PAD_WIDTH + 3))
    local PROMPT_WITH_COLOR
    PROMPT_WITH_COLOR=$(printf "%-*s %s%s%s: " \
                           $ADJUSTED_WIDTH \
                           "$PROMPT_MESSAGE" \
                           "$COLOR" \
                           "$DEFAULT_VALUE" \
                           "$RESET")
    echo "$PROMPT_WITH_COLOR"
}

# Prompt for mandatory input (e.g. passwords), input is hidden
function prompt_mandatory {
    local PROMPT_MESSAGE=$1
    local PAD_WIDTH=${2:-20}
    local INPUT=""

    while [ -z "$INPUT" ]; do
        local PROMPT_WITH_COLOR
        PROMPT_WITH_COLOR=$(printf "%-*s: " $PAD_WIDTH "$PROMPT_MESSAGE")
        read -s -p "$(echo -e "$PROMPT_WITH_COLOR")" INPUT
        echo  # newline after hidden input
        if [ -z "$INPUT" ]; then
            echo "The field $PROMPT_MESSAGE may not be empty. Please enter again."
        fi
    done
    echo "$INPUT"
}

# Prompt the user with specific options and return the response in lowercase
function prompt_user() {
    local prompt_message="$1"
    local options="$2"
    local default_response="$3"
    
    read -p "$prompt_message ($options): " RESPONSE
    RESPONSE=${RESPONSE,,}  # Convert to lowercase
    echo "${RESPONSE:-$default_response}"
}

# ------------------------------------------------------------------------------
# Function to edit an existing .env file (create a backup and load its values)
# ------------------------------------------------------------------------------
function edit_env_file() {
    # Create backup
    mkdir -p "$BACKUP_DIR"
    local TIMESTAMP
    TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
    local BACKUP_FILE="${BACKUP_DIR}/.env.backup-${TIMESTAMP}"
    cp "$ENV_FILE" "$BACKUP_FILE" || error_exit "Error creating backup copy."
    echo "Backup copy created under $BACKUP_FILE."

    # Read existing .env and export variables
    echo "Reading existing .env to use its values as defaults..."
    while IFS='=' read -r key value || [[ -n "$key" ]]; do
        # Skip empty lines and comments
        [[ -z "$key" || "$key" =~ ^# ]] && continue
        # Remove surrounding quotes if any
        value=${value#\"}
        value=${value%\"}
        value=${value#\'}
        value=${value%\'}
        export "$key=$value"
    done < "$ENV_FILE"
}

# ------------------------------------------------------------------------------
# Function to handle user cancellation
# ------------------------------------------------------------------------------
function cancel_operation() {
    echo "Operation cancelled by user."
    exit "$EXIT_USER_CANCEL"
}

# ------------------------------------------------------------------------------
# Main Logic
# ------------------------------------------------------------------------------
if [ -f "$ENV_FILE" ]; then
    RESPONSE=$(prompt_user "Edit: ${ENV_FILE} type <e> | Hold: type <enter> or <u> | Cancel: type <c>" "Edit/Use/Cancel" "use")
    case "$RESPONSE" in
        edit|e)
            edit_env_file
            ;;
        use|u)
            echo "Existing ${ENV_FILE} file will be used (unchanged)."
            exit 0
            ;;
        cancel|c)
            cancel_operation
            ;;
        *)
            echo "Unknown input - existing ${ENV_FILE} will be used (unchanged)."
            exit 0
            ;;
    esac
else
    echo "No ${ENV_FILE} file found."
    RESPONSE=$(prompt_user "Create new: ${ENV_FILE} type <e> | Cancel: type <c>" "Edit/Cancel" "edit")
    case "$RESPONSE" in
        edit|e)
            echo "Proceeding to create a new ${ENV_FILE} file..."
            ;;
        cancel|c)
            cancel_operation
            ;;
        *)
            echo "Unknown input - proceeding to create a new ${ENV_FILE} file."
            ;;
    esac
fi

# ------------------------------------------------------------------------------
# Internal use: Retrieve git info
# ------------------------------------------------------------------------------
DOCKER_BUILDENV_GIT_URL="$(git config --get remote.origin.url)"
DOCKER_BUILDENV_VERSION="$(git -C "$(pwd)" describe --tags --long | sed -e 's/-g[0-9a-f]\{7,\}$//' -e 's/-\([0-9]\+\)$/.\1/')"

# ------------------------------------------------------------------------------
# Original defaults used for prompts (for color comparison and fallback)
# ------------------------------------------------------------------------------
ORIG_USER_NAME="$(whoami)"
ORIG_USER_ID="$(id -u)"
ORIG_USER_GROUP="$(id -gn)"
ORIG_USER_GROUP_ID="$(id -g)"
ORIG_DEFAULT_PASSWORD="tuxpwd"

if command -v git &>/dev/null; then
    ORIG_GIT_EMAIL=$(git config --global user.email || true)
    ORIG_GIT_USER=$(git config --global user.name || true)
fi
ORIG_GIT_EMAIL=${ORIG_GIT_EMAIL:-"${USER}@${HOSTNAME}"}
ORIG_GIT_USER=${ORIG_GIT_USER:-$(getent passwd "${USER}" | cut -d: -f5 | cut -d, -f1)}

ORIG_BUILDENV_GIT_URL="https://github.com/tuxbox-neutrino/buildenv.git"
ORIG_BUILDENV_PREFIX="buildenv"

# Additional defaults
ORIG_DISPLAY="${DISPLAY:-:0}"
ORIG_ENABLE_UI_TOOLS="false"
ORIG_BUILDENV_INSTALL_PREFIX="tuxbox"
ORIG_LOCAL_HOSTNAME="${HOSTNAME}"
ORIG_LOCALE_LANG="${LANG:-en_US.UTF-8}"
ORIG_TZ="$(cat /etc/timezone 2>/dev/null || echo 'UTC')"
ORIG_TERM="${TERM:-xterm}"
ORIG_NVIDIA_VISIBLE_DEVICES="all"
ORIG_QT_QUICK_BACKEND="software"
ORIG_QT_XCB_GL_INTEGRATION="xcb_egl"

ORIG_USER_DIR="${HOME}"

ORIG_EXPLORER_ENABLE="false"
ORIG_EXPLORER_GIT_URL="https://github.com/dbt1/tuxbox-explorer.git"

ORIG_XDG_CONFIG_HOME="${ORIG_USER_DIR}/.config"
ORIG_XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR}"

# ------------------------------------------------------------------------------
# Prompt the user for various settings using defaults (either from existing .env or original)
# ------------------------------------------------------------------------------
echo -e "Global user data"
USER_NAME=$(prompt "USER_NAME" "${USER_NAME:-$ORIG_USER_NAME}")
USER_DIR=$(prompt "USER_DIR" "${USER_DIR:-$ORIG_USER_DIR}")
USER_ID=$(prompt "USER_ID" "${USER_ID:-$ORIG_USER_ID}")
USER_GROUP=$(prompt "USER_GROUP" "${USER_GROUP:-$ORIG_USER_GROUP}")
USER_GROUP_ID=$(prompt "USER_GROUP_ID" "${USER_GROUP_ID:-$ORIG_USER_GROUP_ID}")
echo -e ""
echo -e "Set or use this default user password, NOTE: Please change it if you run the container at first time!"
USER_PASSWORD=$(prompt "USER_PASSWORD" "${USER_PASSWORD:-$ORIG_DEFAULT_PASSWORD}")
# Alternatively, you could use prompt_mandatory for hidden password input:
# USER_PASSWORD=$(prompt_mandatory "USER_PASSWORD" 20)

echo -e ""
echo -e "Add some default git user data."
GIT_EMAIL=$(prompt "GIT_EMAIL" "${GIT_EMAIL:-$ORIG_GIT_EMAIL}")
GIT_USER=$(prompt "GIT_USER" "${GIT_USER:-$ORIG_GIT_USER}")

echo -e ""
echo -e "Clone URL for buildenv sources."
BUILDENV_GIT_URL=$(prompt "BUILDENV_GIT_URL" "${BUILDENV_GIT_URL:-$ORIG_BUILDENV_GIT_URL}")

echo -e ""
echo -e "htdoc content for file explorer, allows userfriendly navigation through deploed results"
EXPLORER_ENABLE=$(prompt "EXPLORER_ENABLE" "${EXPLORER_ENABLE:-$ORIG_EXPLORER_ENABLE}")
EXPLORER_GIT_URL=$(prompt "EXPLORER_GIT_URL" "${EXPLORER_GIT_URL:-$ORIG_EXPLORER_GIT_URL}")

echo -e ""
echo -e "Prefix where to install all buildenv stuff within user dir (default: $ORIG_BUILDENV_INSTALL_PREFIX)"
BUILDENV_INSTALL_PREFIX=$(prompt "BUILDENV_INSTALL_PREFIX" "${BUILDENV_INSTALL_PREFIX:-$ORIG_BUILDENV_INSTALL_PREFIX}")

echo -e ""
echo -e "Prefix for buildenv sources (default: $ORIG_BUILDENV_PREFIX)"
BUILDENV_PREFIX=$(prompt "BUILDENV_PREFIX" "${BUILDENV_PREFIX:-$ORIG_BUILDENV_PREFIX}")

echo -e ""
echo -e "UI-related settings."
DISPLAY=$(prompt "DISPLAY" "${DISPLAY:-$ORIG_DISPLAY}")
ENABLE_UI_TOOLS=$(prompt "ENABLE_UI_TOOLS" "${ENABLE_UI_TOOLS:-$ORIG_ENABLE_UI_TOOLS}")
NVIDIA_VISIBLE_DEVICES=$(prompt "NVIDIA_VISIBLE_DEVICES" "${NVIDIA_VISIBLE_DEVICES:-$ORIG_NVIDIA_VISIBLE_DEVICES}")
QT_QUICK_BACKEND=$(prompt "QT_QUICK_BACKEND" "${QT_QUICK_BACKEND:-$ORIG_QT_QUICK_BACKEND}")
QT_XCB_GL_INTEGRATION=$(prompt "QT_XCB_GL_INTEGRATION" "${QT_XCB_GL_INTEGRATION:-$ORIG_QT_XCB_GL_INTEGRATION}")

echo -e ""
echo -e "System variables."
LOCAL_HOSTNAME=$(prompt "LOCAL_HOSTNAME" "${LOCAL_HOSTNAME:-$ORIG_LOCAL_HOSTNAME}")
LOCALE_LANG=$(prompt "LOCALE_LANG" "${LOCALE_LANG:-$ORIG_LOCALE_LANG}")
TZ=$(prompt "TZ" "${TZ:-$ORIG_TZ}")
TERM=$(prompt "TERM" "${TERM:-$ORIG_TERM}")
XDG_CONFIG_HOME=$(prompt "XDG_CONFIG_HOME" "${XDG_CONFIG_HOME:-$ORIG_XDG_CONFIG_HOME}")
XDG_RUNTIME_DIR=$(prompt "XDG_RUNTIME_DIR" "${XDG_RUNTIME_DIR:-$ORIG_XDG_RUNTIME_DIR}")

# Derived variables based on the above
USER_VOLUME_WORKDIR="${USER_DIR}/${BUILDENV_INSTALL_PREFIX}"
USER_VOLUME_DATADIR="${USER_VOLUME_WORKDIR}/.data"
USER_VOLUME_BINDIR="${USER_DIR}/bin"
START_PATH="${USER_VOLUME_WORKDIR}/${BUILDENV_PREFIX}"
WWW_DOCDIR="${USER_VOLUME_WORKDIR}/htdoc"

# Setup history file location
HISTFILE_NAME=".bash_history"
HISTFILE="${USER_VOLUME_DATADIR}/${HISTFILE_NAME}"

# ------------------------------------------------------------------------------
# Write the final .env file
# ------------------------------------------------------------------------------
cat <<EOF > "$ENV_FILE"
# Auto-generated $ENV_FILE file for docker-buildenv
# Do not change manually! Run $0 to generate $ENV_FILE!

DOCKER_BUILDENV_GIT_URL=${DOCKER_BUILDENV_GIT_URL}
DOCKER_BUILDENV_VERSION=${DOCKER_BUILDENV_VERSION}

BUILDENV_GIT_URL=${BUILDENV_GIT_URL}
BUILDENV_PREFIX=${BUILDENV_PREFIX}

USER_NAME=${USER_NAME}
USER_ID=${USER_ID}
USER_GROUP=${USER_GROUP}
USER_GROUP_ID=${USER_GROUP_ID}
USER_PASSWORD=${USER_PASSWORD}

DISPLAY=${DISPLAY}
ENABLE_UI_TOOLS=${ENABLE_UI_TOOLS}
GIT_EMAIL=${GIT_EMAIL}
GIT_USER=${GIT_USER}
HISTFILE_NAME=${HISTFILE_NAME}
HISTFILE=${HISTFILE}
BUILDENV_INSTALL_PREFIX=${BUILDENV_INSTALL_PREFIX}
LOCAL_HOSTNAME=${LOCAL_HOSTNAME}
LOCALE_LANG=${LOCALE_LANG}
TZ=${TZ}
TERM=${TERM}
NVIDIA_VISIBLE_DEVICES=${NVIDIA_VISIBLE_DEVICES}
QT_QUICK_BACKEND=${QT_QUICK_BACKEND}
QT_XCB_GL_INTEGRATION=${QT_XCB_GL_INTEGRATION}
USER_DIR=${USER_DIR}
USER_VOLUME_WORKDIR=${USER_VOLUME_WORKDIR}
USER_VOLUME_DATADIR=${USER_VOLUME_DATADIR}
USER_VOLUME_BINDIR=${USER_VOLUME_BINDIR}
START_PATH=${START_PATH}
WWW_DOCDIR=${WWW_DOCDIR}
EXPLORER_ENABLE=${EXPLORER_ENABLE}
EXPLORER_GIT_URL=${EXPLORER_GIT_URL}
XDG_CONFIG_HOME=${XDG_CONFIG_HOME}
XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}
EOF

echo -e ""
echo -e "$ENV_FILE file was successfully created (or overwritten)."
