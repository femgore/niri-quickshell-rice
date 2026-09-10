#!/usr/bin/env bash

set -u

VIDEO_DIR="$HOME/Videos"
LOG_FILE="/tmp/wf-recorder.log"

mkdir -p "$VIDEO_DIR"

notify_error() {
    notify-send "Recording Error" "$1"
}

# ── STOP ACTIVE RECORDING ───────────────────────────────────────────

if pgrep -x wf-recorder >/dev/null; then
    # SIGINT lets wf-recorder finalize the MP4 properly.
    pkill -INT -x wf-recorder

    notify-send \
        "Recording stopped" \
        "The video was saved in $VIDEO_DIR"

    exit 0
fi

# ── CHECK DEPENDENCIES ──────────────────────────────────────────────

for command in wf-recorder ffmpeg jq pactl notify-send; do
    if ! command -v "$command" >/dev/null 2>&1; then
        notify_error "Missing dependency: $command"
        exit 1
    fi
done

if ! ffmpeg -hide_banner -encoders 2>/dev/null |
    grep -qE '[[:space:]]h264_nvenc[[:space:]]'; then

    notify_error \
        "FFmpeg does not provide the NVIDIA h264_nvenc encoder"

    exit 1
fi

# ── DETECT ACTIVE OUTPUT ────────────────────────────────────────────

OUTPUT=""

if [[ -n "${NIRI_SOCKET:-}" ]] && command -v niri >/dev/null 2>&1; then
    OUTPUT=$(
        niri msg -j focused-output 2>/dev/null |
            jq -r '.name // empty'
    )
fi

if [[ -z "$OUTPUT" ]]; then
    notify_error \
        "Could not determine the focused Niri output"

    exit 1
fi

# Confirm wf-recorder can see the selected output.
if ! wf-recorder --list-output 2>/dev/null |
    grep -Fq "$OUTPUT"; then

    notify_error \
        "wf-recorder could not find output: $OUTPUT"

    exit 1
fi

# ── DETECT DESKTOP AUDIO ────────────────────────────────────────────

DEFAULT_SINK=$(pactl get-default-sink 2>/dev/null)

if [[ -z "$DEFAULT_SINK" ]]; then
    notify_error "Could not determine the default audio output"
    exit 1
fi

AUDIO_SOURCE="${DEFAULT_SINK}.monitor"

if ! pactl list short sources |
    awk '{print $2}' |
    grep -Fxq "$AUDIO_SOURCE"; then

    notify_error \
        "Desktop-audio source was not found: $AUDIO_SOURCE"

    exit 1
fi

# ── START RECORDING ─────────────────────────────────────────────────

FILE="$VIDEO_DIR/recording-$(date +%F_%H-%M-%S).mp4"

: > "$LOG_FILE"

wf-recorder \
    --output="$OUTPUT" \
    --audio="$AUDIO_SOURCE" \
    --codec=h264_nvenc \
    --audio-codec=aac \
    --codec-param=preset=p4 \
    --codec-param=tune=hq \
    --codec-param=rc=vbr \
    --codec-param=cq=23 \
    --file="$FILE" \
    >"$LOG_FILE" 2>&1 &

RECORDER_PID=$!

# Give wf-recorder time to fail if NVENC cannot initialize.
sleep 1

if ! kill -0 "$RECORDER_PID" 2>/dev/null; then
    ERROR_MESSAGE=$(tail -n 4 "$LOG_FILE")

    notify_error \
        "NVENC recording failed:

$ERROR_MESSAGE"

    exit 1
fi

notify-send \
    "Recording started" \
    "Monitor: $OUTPUT
Encoder: NVIDIA H.264 NVENC
File: $FILE" \
    -i media-record
