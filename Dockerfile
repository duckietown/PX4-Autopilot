FROM ubuntu:20.04 AS px4-dev-base

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

RUN apt-get update && \
    apt-get -y --quiet --no-install-recommends install \
        bzip2 \
        ca-certificates \
        ccache \
        cmake \
        cppcheck \
        curl \
        dirmngr \
        doxygen \
        file \
        g++ \
        gcc \
        gdb \
        git \
        gnupg \
        gosu \
        lcov \
        libfreetype6-dev \
        libgtest-dev \
        libpng-dev \
        libssl-dev \
        lsb-release \
        make \
        ninja-build \
        openjdk-8-jdk \
        openjdk-8-jre \
        openssh-client \
        pkg-config \
        python3-dev \
        python3-pip \
        python3-venv \
        rsync \
        shellcheck \
        tzdata \
        unzip \
        valgrind \
        wget \
        xsltproc \
        zip && \
    apt-get -y autoremove && \
    apt-get clean autoclean && \
    rm -rf /var/lib/apt/lists/{apt,dpkg,cache,log} /tmp/* /var/tmp/*

RUN cd /usr/src/gtest && \
    mkdir build && \
    cd build && \
    cmake .. && \
    make -j"$(nproc)" && \
    find . -name \*.a -exec cp {} /usr/lib \; && \
    cd .. && rm -rf build

RUN python3 -m pip install --upgrade pip wheel setuptools

RUN python3 -m pip install argparse argcomplete coverage cerberus empy==3.3.4 jinja2 kconfiglib \
        matplotlib==3.0.* numpy nunavut>=1.1.0 packaging pkgconfig pyros-genmsg pyulog \
        pyyaml requests serial six toml psutil pyulog wheel jsonschema pynacl

RUN ln -s /usr/bin/ccache /usr/lib/ccache/cc && \
    ln -s /usr/bin/ccache /usr/lib/ccache/c++

RUN wget -q https://downloads.sourceforge.net/project/astyle/astyle/astyle%203.1/astyle_3.1_linux.tar.gz -O /tmp/astyle.tar.gz && \
    cd /tmp && tar zxf astyle.tar.gz && \
    cd astyle/src && \
    make -f ../build/gcc/Makefile -j"$(nproc)" && \
    cp bin/astyle /usr/local/bin && \
    rm -rf /tmp/*

RUN useradd --shell /bin/bash -u 1001 -c "" -m user && \
    usermod -a -G dialout user

RUN mkdir /tmp/.X11-unix && \
    chmod 1777 /tmp/.X11-unix && \
    chown -R root:root /tmp/.X11-unix

ENV DISPLAY=:99 \
    CCACHE_UMASK=000 \
    PATH="/usr/lib/ccache:$PATH" \
    TERM=xterm \
    TZ=UTC

EXPOSE 14556/udp
EXPOSE 14557/udp

FROM px4-dev-base AS builder

WORKDIR /workspaces/PX4-Autopilot

COPY . .

RUN git config -f .gitmodules --get-regexp path | \
    awk '{print $2}' | \
    grep -v '^src/drivers/uavcan/libdronecan/libuavcan/dsdl_compiler/pydronecan$' | \
    xargs git submodule update --init && \
    git -C src/modules/mavlink/mavlink submodule update --init && \
    make px4_sitl_default

FROM px4-dev-base

ARG JSBSIM_RELEASE_TAG=v1.1.1a
ARG JSBSIM_DEB_VERSION=1.1.1-134

RUN wget https://packages.osrfoundation.org/gazebo.gpg -O /usr/share/keyrings/pkgs-osrf-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/pkgs-osrf-archive-keyring.gpg] http://packages.osrfoundation.org/gazebo/ubuntu-stable $(lsb_release -cs) main" | \
    tee /etc/apt/sources.list.d/gazebo-stable.list > /dev/null && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get -y --quiet --no-install-recommends install \
        ant \
        binutils \
        bc \
        dirmngr \
        gazebo11 \
        gstreamer1.0-plugins-bad \
        gstreamer1.0-plugins-base \
        gstreamer1.0-plugins-good \
        gstreamer1.0-plugins-ugly \
        libeigen3-dev \
        libgazebo11-dev \
        libgstreamer-plugins-base1.0-dev \
        libimage-exiftool-perl \
        libopencv-dev \
        libxml2-utils \
        mesa-utils \
        protobuf-compiler \
        x-window-system \
        ignition-fortress && \
    apt-get -y autoremove && \
    apt-get clean autoclean && \
    rm -rf /var/lib/apt/lists/{apt,dpkg,cache,log} /tmp/* /var/tmp/*

ENV QT_X11_NO_MITSHM=1
ENV JAVA_TOOL_OPTIONS=-Dfile.encoding=UTF8

RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    if [ "$arch" = "amd64" ]; then \
        wget "https://github.com/JSBSim-Team/jsbsim/releases/download/${JSBSIM_RELEASE_TAG}/JSBSim-devel_${JSBSIM_DEB_VERSION}.focal.${arch}.deb" -O /tmp/jsbsim.deb; \
        dpkg -i /tmp/jsbsim.deb; \
        rm -f /tmp/jsbsim.deb; \
    else \
        cd /tmp; \
        wget -q "https://github.com/JSBSim-Team/jsbsim/archive/refs/tags/${JSBSIM_RELEASE_TAG}.tar.gz" -O jsbsim.tar.gz; \
        tar -xzf jsbsim.tar.gz; \
        cd "jsbsim-${JSBSIM_RELEASE_TAG#v}"; \
        cmake -S . -B build -DCMAKE_BUILD_TYPE=Release; \
        cmake --build build -j"$(nproc)"; \
        cmake --install build; \
        ldconfig; \
        rm -rf /tmp/jsbsim*; \
    fi

WORKDIR /workspaces/PX4-Autopilot

# PX4 env
ENV PX4_SIMULATOR=rotorpy \
    PX4_SYS_AUTOSTART=10040

# Copy PX4 build + ROMFS
COPY --from=builder /workspaces/PX4-Autopilot/build ./build
COPY --from=builder /workspaces/PX4-Autopilot/ROMFS ./ROMFS

# Copy entrypoint + healthcheck scripts
COPY --from=builder /workspaces/PX4-Autopilot/px4_entrypoint.sh /usr/local/bin/px4_entrypoint.sh
COPY --from=builder /workspaces/PX4-Autopilot/px4_healthcheck.sh /usr/local/bin/px4_healthcheck.sh

# Only virtual Duckiedrones need PX4 SITL.
COPY --from=builder /workspaces/PX4-Autopilot/dt-px4-gate-entrypoint.sh /usr/local/bin/dt-px4-gate-entrypoint.sh
COPY --from=builder /workspaces/PX4-Autopilot/dt-px4-gate-healthcheck.sh /usr/local/bin/dt-px4-gate-healthcheck.sh

RUN chmod +x /usr/local/bin/px4_entrypoint.sh /usr/local/bin/px4_healthcheck.sh \
        /usr/local/bin/dt-px4-gate-entrypoint.sh /usr/local/bin/dt-px4-gate-healthcheck.sh && \
    ldd ./build/px4_sitl_default/bin/px4

# Healthcheck:
# - Healthy once "Waiting for simulator to accept connection on TCP port 4560" appears
# - Unhealthy if "poll timeout" appears AFTER "Ready for takeoff!"
HEALTHCHECK --interval=20s --timeout=5s --start-period=60s --retries=1 \
    CMD /usr/local/bin/dt-px4-gate-healthcheck.sh

# Use wrapper so we can tee PX4 output to a log file
ENTRYPOINT ["/usr/local/bin/dt-px4-gate-entrypoint.sh"]
