#!/usr/bin/env bash

set -u

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/recording"
PID_FILE="$CACHE_DIR/replay_pid"

if [[ ! -f "$PID_FILE" ]]; then
    notify-send \
        -u critical \
        -a "Instant Replay" \
        "Replay is not active" \
        "Start the replay buffer first."

    exit 1
fi

pid="$(cat "$PID_FILE" 2>/dev/null)"

if [[ -z "$pid" ]] || ! kill -0 "$pid" 2>/dev/null; then
    rm -f "$PID_FILE"

    notify-send \
        -u critical \
        -a "Instant Replay" \
        "Replay is not active" \
        "The replay process is no longer running."

    exit 1
fi

kill -SIGUSR1 "$pid"

notify-send \
    -a "Instant Replay" \
    "Replay saved" \
    "Saved the most recent 2 minutes."
