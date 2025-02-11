# Dockerfile for Debian-based Tuxbox build environment
FROM dbt1/debian-tuxbox-base:v1.6

## Build arguments from docker-compose ##

# Internal information
ARG DOCKER_BUILDENV_VERSION=${DOCKER_BUILDENV_VERSION}
ARG DOCKER_BUILDENV_GIT_URL=$DOCKER_BUILDENV_GIT_URL

# URL to buildenv sources and where to install
ARG BUILDENV_GIT_URL=${BUILDENV_GIT_URL}
ARG BUILDENV_PREFIX=${BUILDENV_PREFIX}

# User and group
ARG USER_NAME=${USER_NAME}
ARG USER_ID=${USER_ID}
ARG USER_GROUP=${USER_GROUP}
ARG USER_GROUP_ID=${USER_GROUP_ID}
ARG USER_PASSWORD=${USER_PASSWORD}
ARG USER_DIR=${USER_DIR}

# More build args
ARG DISPLAY=${DISPLAY}
ARG ENABLE_UI_TOOLS=${ENABLE_UI_TOOLS}
ARG GIT_EMAIL=${GIT_EMAIL}
ARG GIT_USER=${GIT_USER}
ARG HISTFILE_NAME=${HISTFILE_NAME}
ARG HISTFILE=${HISTFILE}
ARG BUILDENV_INSTALL_PREFIX=${BUILDENV_INSTALL_PREFIX}
ARG LOCAL_HOSTNAME=${LOCAL_HOSTNAME}
ARG LOCALE_LANG=${LOCALE_LANG}
ARG TZ=${TZ}
ARG TERM=${TERM}
ARG NVIDIA_VISIBLE_DEVICES=${NVIDIA_VISIBLE_DEVICES}
ARG QT_QUICK_BACKEND=${QT_QUICK_BACKEND}
ARG QT_XCB_GL_INTEGRATION=${QT_XCB_GL_INTEGRATION}
ARG USER_VOLUME_WORKDIR=${USER_VOLUME_WORKDIR}
ARG USER_VOLUME_DATADIR=${USER_VOLUME_DATADIR}
ARG START_PATH=${START_PATH}
ARG WWW_DOCDIR=${WWW_DOCDIR}
ARG EXPLORER_ENABLE=${EXPLORER_ENABLE}
ARG EXPLORER_GIT_URL=${EXPLORER_GIT_URL}
ARG XDG_CONFIG_HOME=${XDG_CONFIG_HOME}
ARG XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}

# Convert ARG to ENV for runtime usage
ENV DOCKER_BUILDENV_VERSION=${DOCKER_BUILDENV_VERSION}
ENV DISPLAY=${DISPLAY}
ENV DOCKER_BUILDENV_GIT_URL=$DOCKER_BUILDENV_GIT_URL
ENV BUILDENV_GIT_URL=$BUILDENV_GIT_URL
ENV ENABLE_UI_TOOLS=${ENABLE_UI_TOOLS}
ENV GIT_EMAIL=${GIT_EMAIL}
ENV GIT_USER=${GIT_USER}
ENV HISTFILE_NAME=${HISTFILE_NAME}
ENV HISTFILE=${HISTFILE}
ENV BUILDENV_INSTALL_PREFIX=${BUILDENV_INSTALL_PREFIX}
ENV LOCAL_HOSTNAME=${LOCAL_HOSTNAME}
ENV LOCALE_LANG=${LOCALE_LANG}
ENV TZ=${TZ}
ENV TERM=${TERM}
ENV NVIDIA_VISIBLE_DEVICES=${NVIDIA_VISIBLE_DEVICES}
ENV QT_QUICK_BACKEND=${QT_QUICK_BACKEND}
ENV QT_XCB_GL_INTEGRATION=${QT_XCB_GL_INTEGRATION}
ENV USER=${USER_NAME}
ENV USER_ID=${USER_ID}
ENV USER_GROUP=${USER_GROUP}
ENV USER_GROUP_ID=${USER_GROUP_ID}
ENV USER_PASSWORD=${USER_PASSWORD}
ENV USER_DIR=${USER_DIR}
ENV USER_VOLUME_WORKDIR=${USER_VOLUME_WORKDIR}
ENV USER_VOLUME_DATADIR=${USER_VOLUME_DATADIR}
ENV START_PATH=${START_PATH}
ENV WWW_DOCDIR=${WWW_DOCDIR}
ENV EXPLORER_ENABLE=${EXPLORER_ENABLE}
ENV EXPLORER_GIT_URL=${EXPLORER_GIT_URL}
ENV XDG_CONFIG_HOME=${XDG_CONFIG_HOME}
ENV XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}

# Create user and group
RUN groupadd -g "${USER_GROUP_ID}" "${USER_GROUP}" && \
    useradd -m -u "${USER_ID}" -g "${USER_GROUP_ID}" -s /bin/bash "${USER}" && \
    echo "${USER}:${USER_PASSWORD}" | chpasswd

# Set Locale
RUN sed -i "/${LOCALE_LANG}/s/^# //g" /etc/locale.gen && \
    locale-gen ${LOCALE_LANG} && \
    update-locale LANG="${LOCALE_LANG}"

# Install UI tools (if enabled)
RUN if [ "${ENABLE_UI_TOOLS}" = "true" ]; then \
    apt-get update && apt-get install -y --no-install-recommends \
    breeze-icon-theme \
    meld \
    dbus \
    kdevelop; \
    fi

## avoid dbus warn messages
ENV NO_AT_BRIDGE=1
## Create some basic directories and permissions for X-Server
RUN mkdir -p "${XDG_RUNTIME_DIR}" && chown -R root:root "${XDG_RUNTIME_DIR}" && chmod 0700 "${XDG_RUNTIME_DIR}"

## Copy welcome message
ENV BANNER_FILE=/etc/welcome.txt
COPY files/terminal-splash.txt /etc/terminal-splash.txt
RUN cat /etc/terminal-splash.txt > ${BANNER_FILE} &&  \
    echo "--------------------------------------------------------------" >> ${BANNER_FILE} &&  \
    echo "Tuxbox docker-buildenv: v${DOCKER_BUILDENV_VERSION}" >> ${BANNER_FILE} &&  \
    echo "--------------------------------------------------------------" >> ${BANNER_FILE}

# ssh service setup
ENV SSHD_RUN_SERVICE_DIR="/etc/service/sshd"
ENV SSHD_RUN="${SSHD_RUN_SERVICE_DIR}/run"
RUN mkdir -p /var/run/sshd && \
    ssh-keygen -A && \
    mkdir -p "${SSHD_RUN_SERVICE_DIR}" && \
    echo '#!/bin/sh' > "${SSHD_RUN}" && \
    echo 'exec /usr/sbin/sshd -D' >> "${SSHD_RUN}" && \
    chmod 755 "${SSHD_RUN}"

# Set timezone
RUN ln -snf /usr/share/zoneinfo/"${TZ}" /etc/localtime && echo "${TZ}" > /etc/timezone

# Lighttpd setup
RUN apt update && apt install -y php-cgi php-cli php-common php-fpm php-mbstring && \
    lighty-enable-mod fastcgi && \
    lighty-enable-mod fastcgi-php && \ 
    mkdir -p /run/lighttpd  && \
    chown -R www-data:www-data /run/lighttpd  && \
    chmod -R 755 /run/lighttpd
ENV LIGHTTPD_SERVICE_RUN="/etc/service/lighttpd/run"
ENV LIGHTTPD_CONFIG_PATH="/config/lighttpd"
ENV LIGHTTPD_STD_CONFIG_FILE="${LIGHTTPD_CONFIG_PATH}/lighttpd.conf"
ENV LIGHTTPD_ERROR_DOC="404.html"
RUN mkdir -p /etc/service/lighttpd && \
    echo '#!/bin/sh' > "${LIGHTTPD_SERVICE_RUN}" && \
    echo "if [ ! -d ${LIGHTTPD_CONFIG_PATH} ]; then" >> "${LIGHTTPD_SERVICE_RUN}" && \
    echo "  mkdir -p ${LIGHTTPD_CONFIG_PATH}" >> "${LIGHTTPD_SERVICE_RUN}" && \
    echo "fi" >> "${LIGHTTPD_SERVICE_RUN}" && \
    echo "" >> "${LIGHTTPD_SERVICE_RUN}" && \
    echo "if [ ! -f ${LIGHTTPD_STD_CONFIG_FILE} ]; then" >> "${LIGHTTPD_SERVICE_RUN}" && \
    echo "  cp /etc/lighttpd/lighttpd.conf ${LIGHTTPD_STD_CONFIG_FILE}" >> "${LIGHTTPD_SERVICE_RUN}" && \
    echo "  echo 'dir-listing.activate = \"enable\"' >> ${LIGHTTPD_STD_CONFIG_FILE}" >> "${LIGHTTPD_SERVICE_RUN}" && \
    echo "  echo 'server.follow-symlink = \"enable\"' >> ${LIGHTTPD_STD_CONFIG_FILE}" >> "${LIGHTTPD_SERVICE_RUN}" && \
    echo "  echo 'server.error-handler-404 = \"/${LIGHTTPD_ERROR_DOC}\"' >> ${LIGHTTPD_STD_CONFIG_FILE}" >> "${LIGHTTPD_SERVICE_RUN}" && \
    echo "  sed -i 's|/var/www/html|${WWW_DOCDIR}|g' ${LIGHTTPD_STD_CONFIG_FILE}" >> "${LIGHTTPD_SERVICE_RUN}" && \
    echo "fi" >> "${LIGHTTPD_SERVICE_RUN}" && \
    echo "" >> "${LIGHTTPD_SERVICE_RUN}" && \
    echo "exec lighttpd -D -f ${LIGHTTPD_STD_CONFIG_FILE}" >> "${LIGHTTPD_SERVICE_RUN}" && \
    usermod -aG www-data "${USER}" && \
    chmod 755 "${LIGHTTPD_SERVICE_RUN}"

# Copy helper scripts
COPY files/show-env.sh /usr/local/bin/show-env.sh

# Set the location of the init script and copy the init script from your project into the image
ENV CONTAINER_INIT_SCRIPT="/usr/local/bin/init.sh"
COPY files/init.sh ${CONTAINER_INIT_SCRIPT}
RUN chmod +x ${CONTAINER_INIT_SCRIPT}
COPY files/.bashrc ${USER_DIR}/.bashrc

# Cleanup
RUN apt-get autoremove -y && apt-get autoclean -y && apt-get clean -y && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Make init script executable
RUN chmod 755 "${CONTAINER_INIT_SCRIPT}"

# Start container with init script
ENTRYPOINT ["bash", "-c", "exec ${CONTAINER_INIT_SCRIPT:-/usr/local/bin/init.sh}"]

# Add HEALTHCHECK
HEALTHCHECK --interval=5s --timeout=5s --start-period=1s --retries=10 \
  CMD [ -f /tmp/container_ready ] || exit 1
