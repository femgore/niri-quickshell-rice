#!/usr/bin/env bash
set -euo pipefail

WAL="$HOME/.cache/wal/colors.sh"
OUT="$HOME/.config/niri/colors.kdl"
[[ -f "$WAL" ]] || exit 0

FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS:-}"
LS_COLORS="${LS_COLORS:-}"
source "$WAL"

cat > "$OUT" <<EOF
// Generated from the current Pywal palette.
layout {
    border {
        active-color "$color5"
        inactive-color "$color8"
        urgent-color "$color1"
    }
}
overview { backdrop-color "$background"; }
EOF
