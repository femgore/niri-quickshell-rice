#!/usr/bin/env bash

set -euo pipefail

WALLPAPER="${1:-}"

if [[ -z "$WALLPAPER" || ! -f "$WALLPAPER" ]]; then
    notify-send "Wallpaper Error" "Wallpaper not found: $WALLPAPER"
    exit 1
fi

# Ensure the Awww daemon is running for this Niri session.
if ! awww query >/dev/null 2>&1; then
    pkill -x awww-daemon 2>/dev/null || true

    awww-daemon >/tmp/awww-daemon.log 2>&1 &

    for _ in {1..40}; do
        if awww query >/dev/null 2>&1; then
            break
        fi

        sleep 0.1
    done
fi

if ! awww query >/dev/null 2>&1; then
    notify-send \
        "Wallpaper Error" \
        "Awww daemon did not start. Check /tmp/awww-daemon.log"

    exit 1
fi

# Apply the wallpaper.
awww img "$WALLPAPER" \
    --transition-type grow \
    --transition-pos center \
    --transition-duration 0.75 \
    --transition-fps 60

# Store it so Niri can restore it on the next login.
mkdir -p "$HOME/.cache"
printf '%s\n' "$WALLPAPER" > "$HOME/.cache/current-wallpaper"

persist_path() {
    local file="$1"
    local path="$2"
    local escaped

    [[ -f "$file" ]] || return 0

    escaped=$(printf '%s' "$path" | sed 's/[\/&]/\\&/g')

    sed -i \
        "0,/^[[:space:]]*path[[:space:]]*=.*/s|^[[:space:]]*path[[:space:]]*=.*|    path = $escaped|" \
        "$file"
}

# Keep Hyprpaper and Hyprlock synchronized for seamless session switching.
persist_path "$HOME/.config/niri/wallpaper.conf" "$WALLPAPER"
persist_path "$HOME/.config/niri/hyprlock.conf" "$WALLPAPER"

# Refresh shared Pywal themes.
wal -i "$WALLPAPER" -n -q

"$HOME/.config/niri/scripts/generate-niri-colors.sh" \
    >/dev/null 2>&1 || true

pkill -SIGUSR1 kitty 2>/dev/null || true
