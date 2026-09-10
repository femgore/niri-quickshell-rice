#!/usr/bin/env bash

set -u

VIDEO_DIR="$HOME/Videos"
mkdir -p "$VIDEO_DIR"

# Stop an active wf-recorder cleanly.
if pgrep -x wf-recorder >/dev/null; then
    pkill -INT -x wf-recorder

    notify-send \
        "Recording stopped" \
        "The video was saved in $VIDEO_DIR"

    exit 0
fi

if ! command -v jq >/dev/null; then
    notify-send \
        "Recording Error" \
        "jq is required to detect the active monitor"

    exit 1
fi

# Record the monitor containing the active workspace.
OUTPUT=$(hyprctl activeworkspace -j | jq -r '.monitor // empty')

if [[ -z "$OUTPUT" ]]; then
    notify-send \
        "Recording Error" \
        "Could not determine the active monitor"

    exit 1
fi

FILE="$VIDEO_DIR/recording-$(date +%F_%H-%M-%S).mp4"

# Record the monitor of the current default audio output.
AUDIO_SOURCE="$(pactl get-default-sink).monitor"

if ! pactl list short sources |
    awk '{print $2}' |
    grep -Fxq "$AUDIO_SOURCE"; then

    notify-send \
        "Recording Error" \
        "Desktop-audio source was not found: $AUDIO_SOURCE"

    exit 1
fi

wf-recorder \
    -o "$OUTPUT" \
    --audio="$AUDIO_SOURCE" \
    -f "$FILE" &

notify-send \
    "Recording started" \
    "Monitor: $OUTPUT" \
    -i media-record
