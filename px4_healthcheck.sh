#!/bin/sh
set -eu

LOG_FILE=/var/log/px4_sitl.log

# If the log doesn't exist yet, treat as not ready (health will be 'starting' during start-period)
if [ ! -f "$LOG_FILE" ]; then
  echo "Healthcheck: log file not found yet"
  exit 1
fi

# 1) Did we reach the "Waiting for simulator..." line?
WAIT_LINE=$(
  grep -n "INFO  \[simulator_mavlink\] Waiting for simulator to accept connection on TCP port 4560" "$LOG_FILE" \
    | tail -n 1 \
    | cut -d: -f1 \
    || true
)

if [ -z "$WAIT_LINE" ]; then
  echo "Healthcheck: simulator not yet waiting on TCP port 4560"
  exit 1
fi
