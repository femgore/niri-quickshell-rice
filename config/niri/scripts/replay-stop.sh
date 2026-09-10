#!/usr/bin/env bash

set -u

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/recording"
PID_FILE="$CACHE_DIR/replay_pid"

if [[ ! -f "$PID_FILE" ]]; then
    notify-send \
        -a "Instant Replay" \
        "Replay already disabled" \
        "No replay process is running."

    exit 0
fi

pid="$(cat "$PID_FILE" 2>/dev/null)"

if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
    kill -SIGINT "$pid"
fi

rm -f "$PID_FILE"

notify-send \
    -a "Instant Replay" \
    "Replay disabled" \
    "The replay buffer has stopped."
