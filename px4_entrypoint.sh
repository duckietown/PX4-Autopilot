#!/bin/sh
set -eu

LOG_FILE=/var/log/px4_sitl.log

mkdir -p "$(dirname "$LOG_FILE")"
# Truncate log on each start
: > "$LOG_FILE"

PX4_BIN=./build/px4_sitl_default/bin/px4

# Start PX4 in the background, mirror all output to the log
"$PX4_BIN" "$@" 2>&1 | tee -a "$LOG_FILE" &
PX4_PID=$!

# Monitor for poll timeout after "Startup script returned successfully" line
READY_SEEN=false
while kill -0 "$PX4_PID" 2>/dev/null; do
  sleep 2

  if [ -f "$LOG_FILE" ]; then
    if ! $READY_SEEN && grep -q "Startup script returned successfully" "$LOG_FILE"; then
      READY_SEEN=true
    fi

    # If ready was seen, check for poll timeout AFTER that point
    if $READY_SEEN; then
      READY_LINE=$(grep -n "Startup script returned successfully" "$LOG_FILE" | tail -n 1 | cut -d: -f1)
      if tail -n +"$READY_LINE" "$LOG_FILE" | grep -q "poll timeout"; then
        echo "Poll timeout detected after simulator connected - terminating"
        kill -9 -$PX4_PID 2>/dev/null || true
        exit 1
      fi
    fi
  fi
done

# Wait for PX4 to finish and exit with its status
wait "$PX4_PID"
