#!/usr/bin/env bash
set -u

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

SAVE_DIR="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$SAVE_DIR"

notify_error() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u critical -a "Screenshot" "$1" "$2"
    else
        printf 'Screenshot: %s: %s\n' "$1" "$2" >&2
    fi
}

for cmd in grim slurp magick wl-copy; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        notify_error "Missing dependency" "Cannot take frozen screenshots without: $cmd"
        exit 1
    fi
done

tmp=$(mktemp --suffix=.png "${XDG_RUNTIME_DIR}/niri-frozen-screenshot.XXXXXX")
trap 'rm -f "$tmp"' EXIT

# Capture first, then ask for the area. This preserves hover-only UI.
if ! grim -s 1 -c "$tmp"; then
    notify_error "Screenshot failed" "Could not capture the screen before selection."
    exit 1
fi

geometry=$(slurp -d -f '%x,%y %wx%h') || exit 0

if [[ ! "$geometry" =~ ^(-?[0-9]+),(-?[0-9]+)[[:space:]]+([0-9]+)x([0-9]+)$ ]]; then
    notify_error "Invalid selection" "Received geometry: $geometry"
    exit 1
fi

x="${BASH_REMATCH[1]}"
y="${BASH_REMATCH[2]}"
w="${BASH_REMATCH[3]}"
h="${BASH_REMATCH[4]}"

if (( w < 2 || h < 2 )); then
    exit 0
fi

if (( x < 0 || y < 0 )); then
    notify_error "Unsupported selection" "This helper needs non-negative output coordinates."
    exit 1
fi

file="$SAVE_DIR/Screenshot from $(date +'%Y-%m-%d %H-%M-%S').png"

if ! magick "$tmp" -crop "${w}x${h}+${x}+${y}" +repage "$file"; then
    notify_error "Screenshot failed" "Could not crop the selected area."
    exit 1
fi

if ! wl-copy < "$file"; then
    notify_error "Clipboard copy failed" "Saved the screenshot, but could not copy it."
    exit 1
fi

if command -v notify-send >/dev/null 2>&1; then
    notify-send -a "Screenshot" -i "$file" "Screenshot Saved" "Copied to clipboard and saved to $SAVE_DIR"
fi
