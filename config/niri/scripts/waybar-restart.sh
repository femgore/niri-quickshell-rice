#!/usr/bin/env bash
pkill -x waybar 2>/dev/null || true
sleep 0.2
exec waybar -c "$HOME/.config/niri/waybar/config.jsonc" -s "$HOME/.config/niri/waybar/style.css"
