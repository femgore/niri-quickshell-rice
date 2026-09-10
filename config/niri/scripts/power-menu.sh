#!/usr/bin/env bash
set -euo pipefail

choice=$(printf '%s\n' 'Lock' 'Suspend' 'Reboot' 'Power off' 'Log out' | rofi -dmenu -i -p 'Power') || exit 0
case "$choice" in
    Lock) hyprlock -c "$HOME/.config/niri/hyprlock.conf" ;;
    Suspend) hyprlock -c "$HOME/.config/niri/hyprlock.conf" & sleep 0.5; systemctl suspend ;;
    Reboot) systemctl reboot ;;
    'Power off') systemctl poweroff ;;
    'Log out') niri msg action quit ;;
esac
