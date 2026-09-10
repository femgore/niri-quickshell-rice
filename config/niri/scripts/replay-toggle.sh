#!/usr/bin/env bash

set -u

SCRIPT_DIR="$HOME/.config/niri/scripts"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/recording"
PID_FILE="$CACHE_DIR/replay_pid"

START_SCRIPT="$SCRIPT_DIR/replay-start.sh"
STOP_SCRIPT="$SCRIPT_DIR/replay-stop.sh"

mkdir -p "$CACHE_DIR"

is_replay_running() {
    [[ -f "$PID_FILE" ]] || return 1

    local pid
    pid="$(cat "$PID_FILE" 2>/dev/null)"

    [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

if is_replay_running; then
    exec "$STOP_SCRIPT"
fi

# Remove a stale PID file left behind by a crashed replay process.
rm -f "$PID_FILE"

exec "$START_SCRIPT"
