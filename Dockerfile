FROM px4io/px4-dev-simulation-focal

WORKDIR /workspaces/PX4-Autopilot

# PX4 env
ENV PX4_SIMULATOR=rotorpy \
    PX4_SYS_AUTOSTART=10040

# Copy PX4 build + ROMFS
COPY ./build ./build
COPY ./ROMFS ./ROMFS

# Copy entrypoint + healthcheck scripts
COPY px4_entrypoint.sh /usr/local/bin/px4_entrypoint.sh
COPY px4_healthcheck.sh /usr/local/bin/px4_healthcheck.sh

RUN chmod +x /usr/local/bin/px4_entrypoint.sh /usr/local/bin/px4_healthcheck.sh

# Healthcheck:
# - Healthy once "Waiting for simulator to accept connection on TCP port 4560" appears
# - Unhealthy if "poll timeout" appears AFTER "Ready for takeoff!"
HEALTHCHECK --interval=20s --timeout=5s --start-period=60s --retries=1 \
  CMD /usr/local/bin/px4_healthcheck.sh

# Use wrapper so we can tee PX4 output to a log file
ENTRYPOINT ["/usr/local/bin/px4_entrypoint.sh"]
