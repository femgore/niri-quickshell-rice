#!/usr/bin/env bash

set -u

QS_DIR="$HOME/.config/quickshell"

export IMPERATIVE_COMPOSITOR=niri
pkill -f "$HOME/.config/niri/imperative/scripts/workspaces.sh" \
    2>/dev/null || true

"$HOME/.config/niri/imperative/scripts/workspaces.sh" \
    >"$HOME/.cache/imperative-niri-workspaces.log" 2>&1 &

pkill quickshell 2>/dev/null || true
pkill -f "$HOME/.config/niri/scripts/settings_watcher.sh" \
    2>/dev/null || true

"$HOME/.config/niri/scripts/settings_watcher.sh" \
    >"$HOME/.cache/imperative-settings-watcher.log" 2>&1 &
sleep 0.4
exec "$QS_DIR/launch-igpu.sh" -p "$QS_DIR/Shell.qml"
