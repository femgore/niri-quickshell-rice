#!/usr/bin/env bash
set -euo pipefail

for cmd in grim slurp magick wl-copy; do
    command -v "$cmd" >/dev/null || {
        notify-send "Color Picker" "Missing dependency: $cmd"
        exit 1
    }
done

point=$(slurp -p -f '%x,%y') || exit 0
color=$(grim -g "${point},1x1" -t png - | magick png:- -format '%[pixel:p{0,0}]' info:)
# Convert srgb(r,g,b) into hex.
hex=$(magick -size 1x1 "xc:$color" -format '#%[hex:p{0,0}]' info: | cut -c1-7)
printf '%s' "$hex" | wl-copy
notify-send "Color copied" "$hex"
