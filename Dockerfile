## Use the official Debian 11 image based up debian:bullseye-slim as a base
FROM dbt1/debian-tuxbox-base:v1.6

### Args
ARG PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ARG BUILDENV_GIT_URL=${BUILDENV_GIT_URL}
ARG BUILDENV_VERSION=${BUILDENV_VERSION}
ARG BUILDENV_PREFIX=${BUILDENV_PREFIX}
ARG TB_BUILD_TIME=${TB_BUILD_TIME}
ARG DISPLAY=${DISPLAY}
ARG ENABLE_UI_TOOLS=false
ARG GIT_EMAIL=${GIT_EMAIL}
ARG GIT_USER=${GIT_USER}
ARG USER_GROUP_ID=${USER_GROUP_ID}
ARG HISTFILE=${HISTFILE}
ARG HOST_PREFIX=${HOST_PREFIX}
ARG LOCALE_LANG=${LOCALE_LANG}
ARG LOCAL_HOSTNAME=${LOCAL_HOSTNAME}
ARG NVIDIA_VISIBLE_DEVICES=${NVIDIA_VISIBLE_DEVICES}
ARG QT_QUICK_BACKEND=${QT_QUICK_BACKEND}
ARG QT_XCB_GL_INTEGRATION=${QT_XCB_GL_INTEGRATION}
ARG START_PATH=${START_PATH}
ARG TERM=${TERM}
ARG TZ=${TZ}
ARG USER=${USER}
ARG USER_DIR=${USER_DIR}
ARG USER_GROUP=${USER_GROUP}
ARG USER_ID=${USER_ID}
ARG USER_PASSWORD=${USER_PASSWORD}
ARG USER_VOLUME_WORKDIR=${USER_DIR}/${HOST_PREFIX}
ARG TB_VERSION=${TB_VERSION}
ARG XDG_CONFIG_HOME=${XDG_CONFIG_HOME}
ARG XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}

## Add the user with default password
RUN groupadd -g "${USER_GROUP_ID}" "${USER_GROUP}" && \
    useradd -m -u "${USER_ID}" -g "${USER_GROUP_ID}" -s /bin/bash "${USER}" && \
    echo "${USER}:${USER_PASSWORD}" | chpasswd

## Set the desired Locale
RUN locale-gen ${LOCALE_LANG}  && \
    dpkg-reconfigure --frontend=noninteractive locales && \
    update-locale LANG=${LOCALE_LANG}

### Some labels
LABEL maintainer="Thilo Graf <dbt@novatux.de>" \
      maintainer.org="tuxbox-neutrino" \
      maintainer.org.uri="https://tuxbox-neutrino.org" \
      com.tuxbox-neutrino.project.repo.type="git" \
      com.tuxbox-neutrino.project.repo.uri="https://github.com/dbt1/docker-tuxbox-build" \
      com.tuxbox-neutrino.project.repo.issues="https://github.com/dbt1/docker-tuxbox-build/issues" \
      com.tuxbox-neutrino.app.docker-tuxbox-build.version="${TB_VERSION}" \
      # Open container labels
      org.opencontainers.image.created="${TB_BUILD_TIME}" \
      org.opencontainers.image.description="Debian based" \
      org.opencontainers.image.vendor="tuxbox-neutrino" \
      org.opencontainers.image.source="https://github.com/dbt1/docker-tuxbox-build" \
      # Artifact hub annotations
      io.artifacthub.package.readme-url="https://github.com/dbt1/docker-tuxbox-build/blob/master/README.md" \
      io.artifacthub.package.logo-url="https://avatars.githubusercontent.com/u/22789022?s=200&v=4"

### ui package experimental atm
RUN if [ "$ENABLE_UI_TOOLS" = "true" ]; then \
        apt-get update && apt-get install -y --no-install-recommends \
        breeze-icon-theme \
        meld \
        dbus \
        kdevelop; \
    fi
## avoid dbus warn messages
ENV NO_AT_BRIDGE=1
## Create some basic directories and permissions for X-Server
RUN mkdir -p $XDG_RUNTIME_DIR && chown -R root:root $XDG_RUNTIME_DIR && chmod 0700 $XDG_RUNTIME_DIR

## Copy welcome message
ENV BANNER_FILE=/etc/welcome.txt
COPY terminal-splash.txt /etc/terminal-splash.txt
RUN cat /etc/terminal-splash.txt > ${BANNER_FILE} &&  \
    echo "--------------------------------------------------------------" >> ${BANNER_FILE} &&  \
    echo "Tuxbox-Builder Version: ${TB_VERSION}" >> ${BANNER_FILE} &&  \
    echo "--------------------------------------------------------------" >> ${BANNER_FILE}

### ssh stuff
ENV SSHD_RUN_SERVICE_DIR="/etc/service/sshd"
ENV SSHD_RUN="${SSHD_RUN_SERVICE_DIR}/run"
RUN mkdir /var/run/sshd && \
    ssh-keygen -A && \
    mkdir -p ${SSHD_RUN_SERVICE_DIR} && \
    echo '#!/bin/sh' > ${SSHD_RUN} && \
    echo 'exec /usr/sbin/sshd -D' >> ${SSHD_RUN} && \
    chmod 755 ${SSHD_RUN}

### Set timzone
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

## Lighttpd setup and create the runit service for lighttpd
ENV LIGHTTPD_RUN="/etc/service/lighttpd/run"
ENV LIGHTTPD_CONFIG_PATH="/config/lighttpd"
ENV LIGHTTPD_STD_CONFIG_FILE="${LIGHTTPD_CONFIG_PATH}/lighttpd.conf"
RUN mkdir -p /etc/service/lighttpd && \
    echo '#!/bin/sh' > ${LIGHTTPD_RUN} && \
    echo "if [ ! -d ${LIGHTTPD_CONFIG_PATH} ]; then" >> ${LIGHTTPD_RUN} && \
    echo "  mkdir -p ${LIGHTTPD_CONFIG_PATH}" >> ${LIGHTTPD_RUN} && \
    echo "fi" >> ${LIGHTTPD_RUN} && \
    echo "" >> ${LIGHTTPD_RUN} && \
    echo "if [ ! -f ${LIGHTTPD_STD_CONFIG_FILE} ]; then" >> ${LIGHTTPD_RUN} && \
    echo "  cp /etc/lighttpd/lighttpd.conf ${LIGHTTPD_STD_CONFIG_FILE}" >> ${LIGHTTPD_RUN} && \
    echo "  echo 'dir-listing.activate = \"enable\"' >> ${LIGHTTPD_STD_CONFIG_FILE}" >> ${LIGHTTPD_RUN} && \
    echo "  sed -i 's|/var/www/html|${USER_VOLUME_WORKDIR}/${BUILDENV_PREFIX}/dist|' ${LIGHTTPD_STD_CONFIG_FILE}" >> ${LIGHTTPD_RUN} && \
    echo "fi" >> ${LIGHTTPD_RUN} && \
    echo "" >> ${LIGHTTPD_RUN} && \
    echo "exec lighttpd -D -f ${LIGHTTPD_STD_CONFIG_FILE}" >> ${LIGHTTPD_RUN} && \
    chmod 755 ${LIGHTTPD_RUN}

### Start generate content of start script ###
ENV CONTAINER_INIT_SCRIPT="/usr/local/bin/init.sh"
RUN echo "#!/bin/bash" > ${CONTAINER_INIT_SCRIPT} && \
    echo "echo 'Initialize tuxbox-builder container...'" >> ${CONTAINER_INIT_SCRIPT} && \
    echo "chown -R ${USER}:${USER_GROUP} ${USER_DIR} ${USER_VOLUME_DATADIR}" >> ${CONTAINER_INIT_SCRIPT}  && \
    echo "usermod -aG sudo $USER" >> ${CONTAINER_INIT_SCRIPT}

## prepare git config
RUN mkdir -p ${XDG_CONFIG_HOME}/git && \
    echo "echo -e '[user]\\n\\temail = ${GIT_EMAIL}\\n\\tname = ${GIT_USER}' > ${XDG_CONFIG_HOME}/git/config" >> ${CONTAINER_INIT_SCRIPT} && \
    echo "chown -R ${USER}:${USER_GROUP} ${XDG_CONFIG_HOME}/git" >> ${CONTAINER_INIT_SCRIPT} && \
    echo "echo " >> ${CONTAINER_INIT_SCRIPT}

## Prepare buildenv script
RUN echo "if [ ! -d ${START_PATH}/.git ]; then" >> ${CONTAINER_INIT_SCRIPT} && \
    echo "  echo Cloning buildenv Repository from ${BUILDENV_GIT_URL}" >> ${CONTAINER_INIT_SCRIPT} && \
    echo "  git clone ${BUILDENV_GIT_URL} /tmp/${BUILDENV_PREFIX}" >> ${CONTAINER_INIT_SCRIPT} && \
    echo "  rsync -a /tmp/${BUILDENV_PREFIX} ${USER_VOLUME_WORKDIR}/" >> ${CONTAINER_INIT_SCRIPT} && \
    echo "  rm -rf ${USER_DIR}/${BUILDENV_PREFIX}/tmp" >> ${CONTAINER_INIT_SCRIPT} && \
    echo "else" >> ${CONTAINER_INIT_SCRIPT} && \
    echo "  echo 'Repository [${START_PATH}] already exists. Not touched!'" >> ${CONTAINER_INIT_SCRIPT} && \
    echo "fi" >> ${CONTAINER_INIT_SCRIPT} && \
    echo "chown -R ${USER}:${USER_GROUP} ${USER_VOLUME_WORKDIR}" >> ${CONTAINER_INIT_SCRIPT}

## prepare profile
ENV BASH_RC_FILE=${USER_DIR}/.bashrc
COPY .bashrc ${BASH_RC_FILE}
RUN echo "sed -i 's|@START_PATH@|'"${START_PATH}"'|' ${BASH_RC_FILE}" >> ${CONTAINER_INIT_SCRIPT} && \
    echo "sed -i 's|@VERSION@|'"${TB_VERSION}"'|' ${BASH_RC_FILE}" >> ${CONTAINER_INIT_SCRIPT}  && \
    echo "sed -i 's|@HISTFILE@|'"${HISTFILE}"'|' ${BASH_RC_FILE}" >> ${CONTAINER_INIT_SCRIPT}

## prepare ssh config
RUN echo "mkdir -p ${USER_DIR}/.ssh" >> ${CONTAINER_INIT_SCRIPT}

## show env info
RUN echo "echo " >> ${CONTAINER_INIT_SCRIPT} && \
    echo "echo Environment:" >> ${CONTAINER_INIT_SCRIPT} && \
    echo "echo BUILDENV_VERSION='${BUILDENV_VERSION}'" >> ${CONTAINER_INIT_SCRIPT} && \
    echo "echo HOST_PREFIX='${HOST_PREFIX}'" >> ${CONTAINER_INIT_SCRIPT} && \
    echo "echo BUILDENV_PREFIX='${BUILDENV_PREFIX}'" >> ${CONTAINER_INIT_SCRIPT} && \
    echo "echo BUILDENV_GIT_URL='${BUILDENV_GIT_URL}'" >> ${CONTAINER_INIT_SCRIPT} && \
    echo "echo TZ='${TZ}'" >> ${CONTAINER_INIT_SCRIPT} && \
    echo "echo USER='${USER}'" >> ${CONTAINER_INIT_SCRIPT} && \
    echo "echo USER_GROUP='${USER_GROUP}'" >> ${CONTAINER_INIT_SCRIPT} && \
    echo "echo USER_ID='${USER_ID}'" >> ${CONTAINER_INIT_SCRIPT} && \
    echo "echo USER_GROUP_ID='${USER_GROUP_ID}'" >> ${CONTAINER_INIT_SCRIPT} && \
    echo "echo USER_DIR='${HOME}'" >> ${CONTAINER_INIT_SCRIPT} && \
    echo "echo USER_PASSWORD=******" >> ${CONTAINER_INIT_SCRIPT} && \
    echo "echo HISTFILE='${HISTFILE}'" >> ${CONTAINER_INIT_SCRIPT} && \
    echo "echo GIT_USER='${GIT_USER}'" >> ${CONTAINER_INIT_SCRIPT} && \
    echo "echo GIT_EMAIL='${GIT_EMAIL}'" >> ${CONTAINER_INIT_SCRIPT} && \
    echo "echo PATH='${PATH}'" >> ${CONTAINER_INIT_SCRIPT} && \
    echo "echo LOCALE_LANG='${LOCALE_LANG}'" >> ${CONTAINER_INIT_SCRIPT} && \
    echo "echo START_PATH='${START_PATH}'" >> ${CONTAINER_INIT_SCRIPT} && \
    echo "echo TB_VERSION='${TB_VERSION}'" >> ${CONTAINER_INIT_SCRIPT} && \
    echo "echo TB_BUILD_TIME='${TB_BUILD_TIME}'" >> ${CONTAINER_INIT_SCRIPT} && \
    echo "echo DISPLAY='${DISPLAY}'" >> ${CONTAINER_INIT_SCRIPT} && \
    echo "echo ENABLE_UI_TOOLS='${ENABLE_UI_TOOLS} NOTE: Experimental only!'" >> ${CONTAINER_INIT_SCRIPT} && \
    echo "echo LOCAL_HOSTNAME='${LOCAL_HOSTNAME}'" >> ${CONTAINER_INIT_SCRIPT} && \
    echo "echo HOSTNAME='$HOSTNAME'" >> ${CONTAINER_INIT_SCRIPT} && \
    echo "echo XDG_RUNTIME_DIR='${XDG_RUNTIME_DIR}'" >> ${CONTAINER_INIT_SCRIPT} && \
    echo "echo XDG_CONFIG_HOME='${XDG_CONFIG_HOME}'" >> ${CONTAINER_INIT_SCRIPT} && \
    echo "echo QT_QUICK_BACKEND='${QT_QUICK_BACKEND}'" >> ${CONTAINER_INIT_SCRIPT} && \
    echo "echo QT_XCB_GL_INTEGRATION='${QT_XCB_GL_INTEGRATION}'" >> ${CONTAINER_INIT_SCRIPT} && \
    echo "echo NVIDIA_VISIBLE_DEVICES='${NVIDIA_VISIBLE_DEVICES}'" >> ${CONTAINER_INIT_SCRIPT} && \
    echo "echo " >> ${CONTAINER_INIT_SCRIPT}

## start services
RUN echo "echo 'Ready...'" >> ${CONTAINER_INIT_SCRIPT} && \
    echo "exec runsvdir -P /etc/service" >> ${CONTAINER_INIT_SCRIPT}
### END generate content of start script ###

# clean up
RUN apt-get autoremove -y && apt-get autoclean && apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

## make start script executable
RUN chmod 755 "${CONTAINER_INIT_SCRIPT}"

# Start container with init script
ENTRYPOINT ["bash", "-c", "${CONTAINER_INIT_SCRIPT}"]
CMD ["D"]
