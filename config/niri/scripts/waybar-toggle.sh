#!/usr/bin/env bash
if pgrep -x waybar >/dev/null; then
    pkill -x waybar
else
    waybar -c "$HOME/.config/niri/waybar/config.jsonc" -s "$HOME/.config/niri/waybar/style.css" >/dev/null 2>&1 &
fi
