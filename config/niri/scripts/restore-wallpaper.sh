#!/usr/bin/env bash
set -euo pipefail

CACHE="$HOME/.cache/current-wallpaper"
HYPRPAPER="$HOME/.config/niri/wallpaper.conf"
WALLPAPER=""

if [[ -s "$CACHE" ]]; then
    WALLPAPER=$(head -n1 "$CACHE")
elif [[ -f "$HYPRPAPER" ]]; then
    WALLPAPER=$(sed -n 's/^[[:space:]]*path[[:space:]]*=[[:space:]]*//p' "$HYPRPAPER" | head -n1)
fi

if [[ -n "$WALLPAPER" && -f "$WALLPAPER" ]]; then
    exec "$HOME/.config/niri/scripts/set-wallpaper.sh" "$WALLPAPER"
fi
