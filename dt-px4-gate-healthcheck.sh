#!/bin/sh
set -eu

# Only virtual Duckiedrones need PX4 SITL.
if [ "$(head -1 /data/config/robot_hardware 2>/dev/null)" != "virtual" ]; then
  exit 0
fi

exec /usr/local/bin/px4_healthcheck.sh
