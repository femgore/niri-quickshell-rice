#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ENABLE_FILE="$SCRIPT_DIR/.igpu-device-sandbox-enabled"

case "${1:-}" in
    enable)
        touch "$ENABLE_FILE"
        echo "Quickshell NVIDIA-device isolation enabled for the next start."
        exit 0
        ;;
    disable)
        rm -f "$ENABLE_FILE"
        echo "Quickshell NVIDIA-device isolation disabled for the next start."
        exit 0
        ;;
    status)
        [[ -e "$ENABLE_FILE" ]] && echo enabled || echo disabled
        exit 0
        ;;
esac

if [[ ! -e "$ENABLE_FILE" ]]; then
    exec quickshell "$@"
fi

mask_args=()
while IFS= read -r -d '' node; do
    mask_args+=(--ro-bind /dev/null "$node")
done < <(find /dev -maxdepth 2 -type c -name 'nvidia*' -print0 2>/dev/null)

for drm in /sys/class/drm/card* /sys/class/drm/renderD*; do
    [[ -r "$drm/device/vendor" ]] || continue
    [[ "$(cat "$drm/device/vendor")" == "0x10de" ]] || continue
    node="/dev/dri/$(basename "$drm")"
    [[ -c "$node" ]] && mask_args+=(--ro-bind /dev/null "$node")
done

export DRI_PRIME=0
export QT_FFMPEG_DECODING_HW_DEVICE_TYPES=vaapi
export QT_FFMPEG_ENCODING_HW_DEVICE_TYPES=vaapi

exec bwrap \
    --new-session \
    --bind / / \
    --dev-bind /dev /dev \
    "${mask_args[@]}" \
    quickshell "$@"
