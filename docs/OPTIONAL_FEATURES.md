# Optional Features

## Gaming Rules

`optional/gaming/niri/steam-games.kdl` contains Steam app rules from the original desktop. They are disabled by default because app IDs and resolution requirements are personal.

## Personal Machine Profile

`optional/personal/niri/machine-example.kdl` preserves the original monitor, input, cursor, and workspace feel as an example. It should not be installed by default.

## Hyprland Compatibility

The core rice does not depend on Hyprland. A Hyprland-only Waybar recorder script was moved under:

`optional/hyprland-compat/waybar/scripts/`

Use it only if you intentionally want to reuse pieces with Hyprland.

## Weather

The calendar widget can read OpenWeather values from `~/.config/quickshell/calendar/.env`. The repo does not include `.env` files or API keys.

## NVIDIA Helpers

`config/quickshell/launch-igpu.sh` can isolate Quickshell from NVIDIA device nodes when explicitly enabled by the user. This is optional and hardware-specific.
