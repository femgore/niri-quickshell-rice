#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:-}"
RELOAD_SCRIPT="${2:-$HOME/.config/quickshell/wallpaper/matugen_reload.sh}"
STATE_FILE="$HOME/.config/imperative/color-engine"
LOG_FILE="$HOME/.cache/imperative-color-engine.log"
GENERATOR="$HOME/.config/quickshell/wallpaper/pywal_generate.py"

mkdir -p "$(dirname "$STATE_FILE")" "$(dirname "$LOG_FILE")"
[[ -f "$IMAGE" ]] || { echo "Missing image: $IMAGE" >> "$LOG_FILE"; exit 1; }
ENGINE="$(tr -d '[:space:]' < "$STATE_FILE" 2>/dev/null || true)"
DEFAULT_ENGINE="${QS_COLOR_ENGINE_DEFAULT:-pywal}"
[[ "$DEFAULT_ENGINE" == "pywal" || "$DEFAULT_ENGINE" == "matugen" ]] || DEFAULT_ENGINE="pywal"
[[ "$ENGINE" == "pywal" || "$ENGINE" == "matugen" ]] || ENGINE="$DEFAULT_ENGINE"

{
    echo "[$(date --iso-8601=seconds)] engine=$ENGINE image=$IMAGE"
    if [[ "$ENGINE" == "pywal" ]]; then
        command -v wal >/dev/null 2>&1 || { echo "pywal command 'wal' is not installed"; exit 1; }
        wal -i "$IMAGE" -n -q
        python3 "$GENERATOR"
    else
        command -v matugen >/dev/null 2>&1 || { echo "matugen is not installed"; exit 1; }
        matugen image "$IMAGE" --source-color-index 0
    fi

    [[ -f "$RELOAD_SCRIPT" ]] && bash "$RELOAD_SCRIPT" || true
    echo "done"
} >> "$LOG_FILE" 2>&1
