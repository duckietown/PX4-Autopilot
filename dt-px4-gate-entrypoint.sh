#!/bin/sh
set -eu

# Only virtual Duckiedrones need PX4 SITL.
if [ "$(head -1 /data/config/robot_hardware 2>/dev/null)" = "virtual" ]; then
  exec /usr/local/bin/px4_entrypoint.sh "$@"
fi

echo "dt-px4 (PX4 SITL) not needed on physical Duckiedrones"
exec sleep infinity
