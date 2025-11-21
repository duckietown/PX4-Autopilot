FROM px4io/px4-dev-simulation-focal

COPY ./build /workspaces/PX4-Autopilot/build
COPY ./ROMFS /workspaces/PX4-Autopilot/ROMFS
WORKDIR /workspaces/PX4-Autopilot
ENV PX4SIMULATOR=rotorpy
ENV PX4_SYS_AUTOSTART=10040
ENTRYPOINT ["./build/px4_sitl_default/bin/px4"]
