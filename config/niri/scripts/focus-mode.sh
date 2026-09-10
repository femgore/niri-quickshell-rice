#!/usr/bin/env bash
set -euo pipefail

STATE="$XDG_RUNTIME_DIR/niri-focus-mode"
OUT="$HOME/.config/niri/focus-mode.kdl"

if [[ -f "$STATE" ]]; then
    cat > "$OUT" <<'EOF'
layout {
    gaps 5
    struts { left 5; right 5; top 5; bottom 5; }
    border { on; width 2; }
}
window-rule {
    geometry-corner-radius 15
    clip-to-geometry true
}
EOF
    waybar -c "$HOME/.config/niri/waybar/config.jsonc" -s "$HOME/.config/niri/waybar/style.css" >/dev/null 2>&1 &
    rm -f "$STATE"
else
    cat > "$OUT" <<'EOF'
layout {
    gaps 0
    struts { left 0; right 0; top 0; bottom 0; }
    border { off; }
}
window-rule {
    geometry-corner-radius 0
    clip-to-geometry true
}
EOF
    pkill -x waybar 2>/dev/null || true
    touch "$STATE"
fi
