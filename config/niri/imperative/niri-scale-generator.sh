#!/usr/bin/env bash

set -euo pipefail

SETTINGS="$HOME/.config/quickshell/settings.json"
OUT="$HOME/.config/niri/imperative/generated-scale.kdl"
TMP="${OUT}.tmp"

mkdir -p "$(dirname "$OUT")"

scale="$(
    jq -r '
        .uiScale
        | if type == "number" then . else 1 end
    ' "$SETTINGS"
)"

# Prevent a bad value from making the desktop unusably tiny or huge.
if ! awk -v value="$scale" '
    BEGIN {
        exit !(value >= 0.5 && value <= 3.0)
    }
'; then
    echo "Invalid uiScale: $scale" >&2
    exit 1
fi

outputs="$(niri msg --json outputs)"

{
    echo "// Generated from Imperative Settings uiScale."
    echo "// Do not edit manually."

    jq -r --arg scale "$scale" '
    keys[]
    | "output \(tojson) {\n    mode \"1920x1080@144.003\"\n    scale \($scale)\n}"
' <<<"$outputs"
} > "$TMP"

mv "$TMP" "$OUT"

echo "Updated Niri output scale to $scale"
