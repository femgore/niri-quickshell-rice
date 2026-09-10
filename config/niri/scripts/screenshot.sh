#!/usr/bin/env bash

# Ensure pactl can connect to PipeWire/PulseAudio regardless of launch context
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export PULSE_RUNTIME_PATH="$XDG_RUNTIME_DIR/pulse"

# ---------------------------------------------------------
# CACHING & MIGRATION
# ---------------------------------------------------------
source "$(dirname "${BASH_SOURCE[0]}")/caching.sh"

qs_ensure_cache "screenshot"
qs_ensure_cache "recording"

# ---------------------------------------------------------
# DEPENDENCY CHECK
# ---------------------------------------------------------
# First check for notify-send so we can display errors
if ! command -v notify-send &> /dev/null; then
    echo "ERROR: notify-send is not installed. Cannot display missing dependencies."
    exit 1
fi

REQUIRED_CMDS=("gpu-screen-recorder" "grim" "satty" "wl-copy" "pactl" "quickshell" "zbarimg" "python3" "magick")
MISSING_CMDS=()

for cmd in "${REQUIRED_CMDS[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        MISSING_CMDS+=("$cmd")
    fi
done

if [ ${#MISSING_CMDS[@]} -ne 0 ]; then
    notify-send -u critical -a "Screenshot System" "Missing Dependencies" "Cannot start. Please install:\n${MISSING_CMDS[*]}"
    exit 1
fi
# ---------------------------------------------------------

# Directories
SAVE_DIR="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
RECORD_DIR="${XDG_VIDEOS_DIR:-$HOME/Videos}/Recordings"
CACHE_DIR="$QS_CACHE_RECORDING"
mkdir -p "$SAVE_DIR" "$RECORD_DIR"

# Parse arguments safely upfront
EDIT_MODE=false
FULL_MODE=false
RECORD_MODE=false
SCAN_QR_MODE=false
CLIPBOARD_ONLY=false
GEOMETRY=""
FREEZE_PATH=""
ANNOTATIONS_PATH=""
DESK_VOL="1.0"
DESK_MUTE="false"
MIC_VOL="1.0"
MIC_MUTE="false"
MIC_DEVICE=""

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --edit) EDIT_MODE=true; shift ;;
        --full) FULL_MODE=true; shift ;;
        --record) RECORD_MODE=true; shift ;;
        --scan-qr) SCAN_QR_MODE=true; shift ;;
        --clipboard-only) CLIPBOARD_ONLY=true; shift ;;
        --geometry) GEOMETRY="$2"; shift 2 ;;
        --freeze-path) FREEZE_PATH="$2"; shift 2 ;;
        --annotations) ANNOTATIONS_PATH="$2"; shift 2 ;;
        --desk-vol) DESK_VOL="$2"; shift 2 ;;
        --desk-mute) DESK_MUTE="$2"; shift 2 ;;
        --mic-vol) MIC_VOL="$2"; shift 2 ;;
        --mic-mute) MIC_MUTE="$2"; shift 2 ;;
        --mic-dev) MIC_DEVICE="$2"; shift 2 ;;
        *) shift ;;
    esac
done

# ---------------------------------------------------------
# INSTANT QR SCANNING EXECUTION
# ---------------------------------------------------------
if [ "$SCAN_QR_MODE" = true ]; then
    RES_FILE="$QS_RUN_SCREENSHOT/qr_result"
    export DEBUG_LOG="$QS_LOG_DIR/qr_debug.log"
    rm -f "$RES_FILE" "$DEBUG_LOG"
    
    echo "=== QR SCAN INITIATED $(date) ===" > "$DEBUG_LOG"
    
    if ! command -v zbarimg &> /dev/null; then
        echo -e "0,0,0,0|||ERROR: zbarimg is not installed. Please install it." > "$RES_FILE"
        exit 1
    fi

    TMP_IMG="$QS_RUN_SCREENSHOT/qr_temp_$$.png"
    grim -g "$GEOMETRY" "$TMP_IMG"
    
    export XML_OUT=$(zbarimg --xml -q "$TMP_IMG" 2>>"$DEBUG_LOG")
    
    if [ -n "$XML_OUT" ]; then
        python3 << 'EOF' > "$RES_FILE"
import os, sys, logging, re
import xml.etree.ElementTree as ET

debug_log = os.environ.get("DEBUG_LOG", "/tmp/qs_qr_debug.log")
logging.basicConfig(filename=debug_log, level=logging.DEBUG, format="%(asctime)s - %(levelname)s - %(message)s")

raw_xml = os.environ.get("XML_OUT", "")
if not raw_xml.strip():
    print("0,0,0,0|||ERROR: Empty output from zbarimg. See log.")
    sys.exit(0)

try:
    xml_clean = re.sub(r'\sxmlns="[^"]+"', '', raw_xml)
    xml_clean = re.sub(r"\sxmlns='[^']+'", '', xml_clean)
    tree = ET.fromstring(xml_clean)
    
    found_any = False
    for elem in tree.iter():
        if elem.tag.endswith('symbol'):
            found_any = True
            data_text = ''
            min_x, min_y, max_x, max_y = float('inf'), float('inf'), -float('inf'), -float('inf')
            
            for child in elem:
                if child.tag.endswith('data'):
                    data_text = child.text if child.text else ''
                elif child.tag.endswith('polygon'):
                    pts_str = child.get('points', '')
                    if pts_str:
                        pt_pairs = pts_str.replace('+', '').split(' ')
                        for pair in pt_pairs:
                            if ',' in pair:
                                try:
                                    x_str, y_str = pair.split(',')
                                    x, y = int(x_str), int(y_str)
                                    min_x = min(min_x, x)
                                    max_x = max(max_x, x)
                                    min_y = min(min_y, y)
                                    max_y = max(max_y, y)
                                except ValueError:
                                    pass
            
            if min_x == float('inf'): min_x, min_y, max_x, max_y = 0, 0, 0, 0
            w, h = max_x - min_x, max_y - min_y
            encoded = data_text.replace('\\', '\\\\').replace('\n', '\\n').replace('\r', '')
            print(f"{int(min_x)},{int(min_y)},{int(w)},{int(h)}|||{encoded}")

    if not found_any: print("0,0,0,0|||NOT_FOUND")
except Exception as e:
    print(f"0,0,0,0|||ERROR: XML Parse failure: {e}. Check log.")
EOF
    else
        echo -e "0,0,0,0|||NOT_FOUND" > "$RES_FILE"
    fi
    
    rm -f "$TMP_IMG"
    exit 0
fi

# ---------------------------------------------------------
# SMART TOGGLE: STOP RECORDING & CLEANUP VIRTUAL AUDIO
# ---------------------------------------------------------
if [ -f "$CACHE_DIR/rec_pid" ]; then
    # PREVENT OVERLAPPING EXECUTIONS
    if [ -f "$CACHE_DIR/processing.lock" ]; then exit 0; fi
    touch "$CACHE_DIR/processing.lock"

    REC_PID=$(cat "$CACHE_DIR/rec_pid")
    FINAL_FILE=$(cat "$CACHE_DIR/final_file")

    # 1. Ask GPU Screen Recorder to stop and finalize normally.
if [[ "$REC_PID" != "0" ]] && kill -0 "$REC_PID" 2>/dev/null; then
    kill -SIGINT "$REC_PID" 2>/dev/null || true
fi

# 2. Wait up to 30 actual seconds for MP4 finalization.
remaining=300

while kill -0 "$REC_PID" 2>/dev/null && (( remaining > 0 )); do
    sleep 0.1
    ((remaining--))
done

# Only force-kill if it genuinely remains stuck after 30 seconds.
if kill -0 "$REC_PID" 2>/dev/null; then
    kill -TERM "$REC_PID" 2>/dev/null || true
    sleep 2
fi

if kill -0 "$REC_PID" 2>/dev/null; then
    kill -KILL "$REC_PID" 2>/dev/null || true
fi
    # 3. DESTROY PIPEWIRE VIRTUAL AUDIO CABLES
    if [ -f "$CACHE_DIR/pw_modules" ]; then
        while read -r mod_id; do
            [ -n "$mod_id" ] && pactl unload-module "$mod_id" 2>/dev/null
        done < "$CACHE_DIR/pw_modules"
        rm -f "$CACHE_DIR/pw_modules"
    fi

    # 4. SEND FINAL NOTIFICATION
    if [[ -s "$FINAL_FILE" ]]; then
        (
            ACTION=$(notify-send -a "Screen Recorder" -i "$FINAL_FILE" -A "default=Open Folder" "⏺ Recording Saved" "File: $(basename "$FINAL_FILE")\nFolder: $RECORD_DIR")
            if [ "$ACTION" = "default" ]; then
                if command -v nautilus &> /dev/null; then
                    nautilus "$RECORD_DIR"
                else
                    xdg-open "$RECORD_DIR"
                fi
            fi
        ) &
    else
        notify-send -a "Screen Recorder" "❌ Error" "Failed to save the video file."
    fi

    # 5. INSTANT UI CLEANUP
    rm -f "$CACHE_DIR/processing.lock"
    rm -f "$CACHE_DIR/rec_pid" "$CACHE_DIR/final_file"
    exit 0
fi

time=$(date +'%Y-%m-%d-%H%M%S')
FILENAME="$SAVE_DIR/Screenshot_$time.png"
VID_FILENAME="$RECORD_DIR/Recording_$time.mp4"
CACHE_FILE="$QS_CACHE_SCREENSHOT/geometry"
MODE_CACHE_FILE="$QS_CACHE_SCREENSHOT/video_mode"

cleanup_capture_files() {
    [[ -n "$FREEZE_PATH" && "$FREEZE_PATH" == "$QS_RUN_SCREENSHOT"/freeze-*.png ]] && rm -f "$FREEZE_PATH"
    [[ -n "$ANNOTATIONS_PATH" && "$ANNOTATIONS_PATH" == "$QS_RUN_SCREENSHOT"/annotations-*.json ]] && rm -f "$ANNOTATIONS_PATH"
}

if [[ -n "$FREEZE_PATH" || -n "$ANNOTATIONS_PATH" ]]; then
    trap cleanup_capture_files EXIT
fi

rm -f "$CACHE_DIR/processing.lock"

# ---------------------------------------------------------
# PHASE 1: Capture Execution (GPU-Screen-Recorder + Virtual Audio)
# ---------------------------------------------------------
if [ "$FULL_MODE" = true ] || [ -n "$GEOMETRY" ]; then

    if [ "$RECORD_MODE" = true ]; then
        
        # Clear out any old module IDs
        echo -n "" > "$CACHE_DIR/pw_modules"

        DESK_SINK=$(pactl get-default-sink 2>/dev/null)
        [ -n "$DESK_SINK" ] && DESK_DEV="${DESK_SINK}.monitor" || DESK_DEV=""
        
        [ -n "$MIC_DEVICE" ] && [ "$MIC_DEVICE" != "null" ] && MIC_DEV="$MIC_DEVICE" || MIC_DEV=$(pactl get-default-source 2>/dev/null)
        MIC_DEV="${MIC_DEV:-default}"

        # Choose the capture target.
        #
        # Quickshell/Grim passes geometry as:
        #   X,Y WIDTHxHEIGHT
        #
        # gpu-screen-recorder expects a region as:
        #   WIDTHxHEIGHT+X+Y
        if [ -n "$GEOMETRY" ]; then
            if [[ "$GEOMETRY" =~ ^[[:space:]]*(-?[0-9]+),(-?[0-9]+)[[:space:]]+([0-9]+)x([0-9]+)[[:space:]]*$ ]]; then
                REGION_X="${BASH_REMATCH[1]}"
                REGION_Y="${BASH_REMATCH[2]}"
                REGION_W="${BASH_REMATCH[3]}"
                REGION_H="${BASH_REMATCH[4]}"

                # Reject empty or invalid selections.
                if (( REGION_W < 2 || REGION_H < 2 )); then
                    notify-send \
                        -u critical \
                        -a "Screen Recorder" \
                        "Invalid recording region" \
                        "The selected area is too small."
                    exit 1
                fi

                GSR_REGION="${REGION_W}x${REGION_H}+${REGION_X}+${REGION_Y}"

                GSR_ARGS=(
                    -w region
                    -region "$GSR_REGION"
                    -c mp4
                    -f 60
                    -ac aac
                )
            else
                notify-send \
                    -u critical \
                    -a "Screen Recorder" \
                    "Invalid recording region" \
                    "Received geometry: $GEOMETRY"
                exit 1
            fi
        elif [ "$FULL_MODE" = true ]; then
            # Retain portal capture only for an explicit --full invocation
            # where no QML geometry was supplied.
            GSR_ARGS=(
                -w portal
                -restore-portal-session yes
                -c mp4
                -f 60
                -ac aac
            )
        else
            notify-send \
                -u critical \
                -a "Screen Recorder" \
                "No recording region" \
                "Select an area before starting the recording."
            exit 1
        fi

        AUDIO_MIX=""

        # --- DESKTOP AUDIO VIRTUAL ROUTING ---
        if [ "$DESK_MUTE" != "true" ] && [ -n "$DESK_DEV" ]; then
            # Create a virtual sink
            D_SINK_ID=$(pactl load-module module-null-sink sink_name=qs_virt_desk sink_properties=device.description="QS_Virtual_Desk")
            # Loop the real desktop audio into the virtual sink
            D_LOOP_ID=$(pactl load-module module-loopback source="$DESK_DEV" sink=qs_virt_desk)
            
            # Linearize volume calculation (0 - 65536) to prevent PulseAudio's steep cubic drop-off at 25%
            D_VOL_INT=$(awk "BEGIN {print int(${DESK_VOL//,/.} * 65536)}")
            pactl set-sink-volume qs_virt_desk "$D_VOL_INT"
            
            # Save IDs for teardown
            echo "$D_SINK_ID" >> "$CACHE_DIR/pw_modules"
            echo "$D_LOOP_ID" >> "$CACHE_DIR/pw_modules"
            
            # Append to mixing string
            AUDIO_MIX="${AUDIO_MIX}qs_virt_desk.monitor|"
        fi

        # --- MICROPHONE VIRTUAL ROUTING ---
        if [ "$MIC_MUTE" != "true" ] && [ -n "$MIC_DEV" ]; then
            # Create a virtual sink for the mic
            M_SINK_ID=$(pactl load-module module-null-sink sink_name=qs_virt_mic sink_properties=device.description="QS_Virtual_Mic")
            # Loop the real mic into the virtual sink
            M_LOOP_ID=$(pactl load-module module-loopback source="$MIC_DEV" sink=qs_virt_mic)
            
            # Linearize volume calculation (0 - 65536) to prevent PulseAudio's steep cubic drop-off
            M_VOL_INT=$(awk "BEGIN {print int(${MIC_VOL//,/.} * 65536)}")
            pactl set-sink-volume qs_virt_mic "$M_VOL_INT"
            
            # Save IDs for teardown
            echo "$M_SINK_ID" >> "$CACHE_DIR/pw_modules"
            echo "$M_LOOP_ID" >> "$CACHE_DIR/pw_modules"
            
            # Append to mixing string
            AUDIO_MIX="${AUDIO_MIX}qs_virt_mic.monitor|"
        fi

        # Remove trailing pipe and add the single mix string to the recorder so everything stays on one track
        AUDIO_MIX=${AUDIO_MIX%|}
        if [ -n "$AUDIO_MIX" ]; then
            GSR_ARGS+=(-a "$AUDIO_MIX")
        fi

        # Execute gpu-screen-recorder
GSR_LOG="$CACHE_DIR/gpu-screen-recorder.log"
rm -f "$GSR_LOG"

gpu-screen-recorder "${GSR_ARGS[@]}" \
    -o "$VID_FILENAME" \
    >"$GSR_LOG" 2>&1 &

REC_PID=$!

# Give it time to initialize and fail visibly if portal/audio setup is bad.
sleep 1

if ! kill -0 "$REC_PID" 2>/dev/null; then
    ERROR_TEXT="$(tail -n 8 "$GSR_LOG" 2>/dev/null)"

    notify-send \
        -u critical \
        -a "Screen Recorder" \
        "Recording failed to start" \
        "${ERROR_TEXT:-See $GSR_LOG}"

    if [[ -f "$CACHE_DIR/pw_modules" ]]; then
        while read -r mod_id; do
            [[ -n "$mod_id" ]] &&
                pactl unload-module "$mod_id" 2>/dev/null || true
        done < "$CACHE_DIR/pw_modules"
    fi

    rm -f \
        "$CACHE_DIR/pw_modules" \
        "$CACHE_DIR/rec_pid" \
        "$CACHE_DIR/final_file"

    exit 1
fi
        echo "$REC_PID" > "$CACHE_DIR/rec_pid"
        echo "$VID_FILENAME" > "$CACHE_DIR/final_file"

        notify-send -a "Screen Recorder" "⏺ Recording Started" "Press your screenshot shortcut again to stop."
        exit 0
    fi

    # Mode: Screenshot
    capture_png() {
        if [ -n "$ANNOTATIONS_PATH" ]; then
            if [ -z "$FREEZE_PATH" ] || [ ! -f "$FREEZE_PATH" ]; then
                notify-send -u critical -a "Screenshot" "Screenshot Failed" "Annotations require a frozen screen image."
                return 1
            fi
            if [ ! -f "$ANNOTATIONS_PATH" ]; then
                notify-send -u critical -a "Screenshot" "Screenshot Failed" "The censor drawing data is missing."
                return 1
            fi
            python3 "$HOME/.config/niri/scripts/screenshot_annotate.py" annotate \
                --image "$FREEZE_PATH" \
                --geometry "$GEOMETRY" \
                --annotations "$ANNOTATIONS_PATH" \
                --output -
        elif [ -n "$FREEZE_PATH" ] && [ -n "$GEOMETRY" ]; then
            if [ ! -f "$FREEZE_PATH" ]; then
                notify-send -u critical -a "Screenshot" "Screenshot Failed" "The frozen screen image is missing."
                return 1
            fi

            if [[ "$GEOMETRY" =~ ^[[:space:]]*(-?[0-9]+),(-?[0-9]+)[[:space:]]+([0-9]+)x([0-9]+)[[:space:]]*$ ]]; then
                magick "$FREEZE_PATH" -crop "${BASH_REMATCH[3]}x${BASH_REMATCH[4]}+${BASH_REMATCH[1]}+${BASH_REMATCH[2]}" +repage png:-
            else
                notify-send -u critical -a "Screenshot" "Invalid selection" "Received geometry: $GEOMETRY"
                return 1
            fi
        elif [ -n "$GEOMETRY" ]; then
            grim -g "$GEOMETRY" -
        else
            grim -
        fi
    }

    if [ "$CLIPBOARD_ONLY" = true ]; then
        # Capture directly to the clipboard without writing a screenshot file.
        # This mode is intended for a dedicated quick-screenshot keybind.
        capture_png | wl-copy
        PIPE_STATUSES=("${PIPESTATUS[@]}")
        CAPTURE_STATUS=${PIPE_STATUSES[0]}
        COPY_STATUS=${PIPE_STATUSES[1]}

        if [ "$CAPTURE_STATUS" -eq 0 ] && [ "$COPY_STATUS" -eq 0 ]; then
            notify-send -a "Screenshot" "Screenshot Copied" "The selected area was copied to the clipboard."
        else
            notify-send -u critical -a "Screenshot" "Screenshot Failed" "The screenshot could not be copied to the clipboard."
        fi

        exit 0
    elif [ "$EDIT_MODE" = true ]; then
        capture_png | GSK_RENDERER=gl satty --filename - --output-filename "$FILENAME" --init-tool brush --copy-command wl-copy
    else
        capture_png | tee "$FILENAME" | wl-copy
    fi

    if [ -s "$FILENAME" ]; then
        (
            ACTION=$(notify-send -a "Screenshot" -i "$FILENAME" -A "default=Open Folder" "Screenshot Saved" "File: Screenshot_$time.png\nFolder: $SAVE_DIR")
            if [ "$ACTION" = "default" ]; then
                if command -v nautilus &> /dev/null; then
                    nautilus "$SAVE_DIR"
                else
                    xdg-open "$SAVE_DIR"
                fi
            fi
        ) &
    fi
    exit 0
fi

# ---------------------------------------------------------
# PHASE 2: UI Trigger (Launch Standalone Quickshell Overlay)
# ---------------------------------------------------------
QML_PATH="$HOME/.config/quickshell/ScreenshotOverlay.qml"
FREEZE_FILE="$QS_RUN_SCREENSHOT/freeze-$$.png"

if pgrep -f "quickshell -p $QML_PATH" > /dev/null; then
    pkill -f "quickshell -p $QML_PATH"
    exit 0
fi

if command -v pactl &> /dev/null; then
    export QS_MIC_LIST=$(pactl list sources short 2>/dev/null | awk '{print $2}' | grep -v '\.monitor$' | while IFS= read -r name; do
        desc=$(pactl list sources 2>/dev/null | awk -v n="$name" '/Name:/ { found = ($2 == n) } found && /Description:/ { sub(/^[[:space:]]*Description:[[:space:]]*/, ""); print; exit }')
        echo "$name|${desc:-$name}"
    done)
else
    export QS_MIC_LIST=""
fi

PREFS="$QS_STATE_SCREENSHOT/audio_prefs"
if [ -f "$PREFS" ]; then
    IFS=',' read -r QS_DESK_VOL QS_DESK_MUTE QS_MIC_VOL QS_MIC_MUTE QS_MIC_DEV < "$PREFS"
    export QS_DESK_VOL QS_DESK_MUTE QS_MIC_VOL QS_MIC_MUTE QS_MIC_DEV
fi

[ "$EDIT_MODE" = true ] && export QS_SCREENSHOT_EDIT="true" || export QS_SCREENSHOT_EDIT="false"
[ "$CLIPBOARD_ONLY" = true ] && export QS_SCREENSHOT_CLIPBOARD_ONLY="true" || export QS_SCREENSHOT_CLIPBOARD_ONLY="false"
if [ "$RECORD_MODE" != true ] && grim -s 1 -c "$FREEZE_FILE"; then
    export QS_SCREENSHOT_FREEZE_PATH="$FREEZE_FILE"
else
    export QS_SCREENSHOT_FREEZE_PATH=""
fi
[ -f "$CACHE_FILE" ] && export QS_CACHED_GEOM=$(cat "$CACHE_FILE") || export QS_CACHED_GEOM=""
[ -f "$MODE_CACHE_FILE" ] && export QS_CACHED_MODE=$(cat "$MODE_CACHE_FILE") || export QS_CACHED_MODE="false"

quickshell -p "$QML_PATH"
