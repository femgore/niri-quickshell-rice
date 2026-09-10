#!/usr/bin/env bash
set -u

SETTINGS_FILE="$HOME/.config/quickshell/settings.json"
ENV_FILE="$HOME/.config/quickshell/calendar/.env"
WEATHER_SCRIPT="$HOME/.config/quickshell/calendar/weather.sh"
GENERATOR="$HOME/.config/niri/imperative/niri-keybind-generator.py"
SCALE_GENERATOR="$HOME/.config/niri/imperative/niri-scale-generator.sh"
compile_niri() {
    local failed=0

    if [[ -x "$GENERATOR" ]]; then
        echo "Regenerating Niri keybindings..."

        if ! "$GENERATOR"; then
            notify-send "Niri keybind error" \
                "The new bindings were rejected. Your previous bindings remain active."
            failed=1
        fi
    fi

    if [[ -n "${NIRI_SOCKET:-}" ]] && [[ -x "$SCALE_GENERATOR" ]]; then
        echo "Regenerating Niri output scale..."

        if ! "$SCALE_GENERATOR"; then
            notify-send "Niri scale error" \
                "The UI scale could not be applied."
            failed=1
        fi
    fi

    return "$failed"
}

compile_all() {
    compile_niri || true
}

if [[ "${1:-}" == "--compile" ]]; then
    compile_all
    exit 0
fi

compile_all

echo "Watching portable Niri/Quickshell settings changes..."

inotifywait -m -q -e close_write,moved_to --format '%w%f' \
    "$(dirname "$SETTINGS_FILE")" "$(dirname "$ENV_FILE")" |
while read -r filepath; do
    if [[ "$filepath" == "$SETTINGS_FILE" ]]; then
        compile_all
    elif [[ "$filepath" == "$ENV_FILE" ]]; then
        echo ".env updated; refreshing weather cache..."
        if [[ -x "$WEATHER_SCRIPT" ]]; then
            "$WEATHER_SCRIPT" --getdata &
        elif [[ -f "$WEATHER_SCRIPT" ]]; then
            bash "$WEATHER_SCRIPT" --getdata &
        fi
    fi
done
