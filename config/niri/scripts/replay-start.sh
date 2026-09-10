#!/usr/bin/env bash

set -u

export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export PULSE_RUNTIME_PATH="$XDG_RUNTIME_DIR/pulse"

REPLAY_DIR="${XDG_VIDEOS_DIR:-$HOME/Videos}/Replays"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/recording"
PID_FILE="$CACHE_DIR/replay_pid"
LOG_FILE="$CACHE_DIR/replay.log"

mkdir -p "$REPLAY_DIR" "$CACHE_DIR"

if [[ -f "$PID_FILE" ]]; then
    pid="$(cat "$PID_FILE" 2>/dev/null)"

    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        notify-send \
            -a "Instant Replay" \
            "Replay already active" \
            "The replay buffer is already running."
        exit 0
    fi

    rm -f "$PID_FILE"
fi

gpu-screen-recorder \
    -w portal \
    -restore-portal-session yes \
    -f 60 \
    -c mp4 \
    -k h264 \
    -a default_output \
    -r 15 \
    -replay-storage ram \
    -restart-replay-on-save no \
    -bm cbr \
    -q 20000 \
    -o "$REPLAY_DIR" \
    >"$LOG_FILE" 2>&1 &

pid=$!
echo "$pid" > "$PID_FILE"

sleep 1

if ! kill -0 "$pid" 2>/dev/null; then
    error_text="$(tail -n 8 "$LOG_FILE" 2>/dev/null)"

    rm -f "$PID_FILE"

    notify-send \
        -u critical \
        -a "Instant Replay" \
        "Replay failed to start" \
        "${error_text:-See $LOG_FILE}"

    exit 1
fi

notify-send \
    -a "Instant Replay" \
    "Replay enabled" \
    "The last 2 minutes can now be saved."
