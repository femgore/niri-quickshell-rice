#!/usr/bin/env bash
set -euo pipefail

lock='pgrep -x hyprlock >/dev/null || hyprlock -c "$HOME/.config/niri/hyprlock.conf"'

exec swayidle -w \
    timeout 300 "sh -c '$lock'" \
    timeout 600 'niri msg action power-off-monitors' \
    timeout 1800 'systemctl suspend' \
    before-sleep "sh -c '$lock'"
