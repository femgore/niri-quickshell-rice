# Configuration

## Layout

| Path | Purpose |
| --- | --- |
| `config/niri/config.kdl` | Main Niri config and default keybindings |
| `config/niri/scripts/` | Niri-owned helper scripts copied from the live setup |
| `config/niri/imperative/` | Settings-generated Niri keybind and scale bridge |
| `config/kitty/` | Kitty transparency and generated color include |
| `config/quickshell/` | Active Quickshell shell, widgets, settings, and color files |
| `config/waybar/scripts/` | Helper scripts used by the optional Niri Waybar config |
| `assets/wallpapers/` | Wallpaper collection copied to `~/Pictures/Wallpapers` by the installer |
| `optional/` | Disabled examples and compatibility snippets |

## Personal Material

Machine-specific monitor, input, cursor, and extended workspace mapping was moved to:

`optional/personal/niri/machine-example.kdl`

Game-specific rules were moved to:

`optional/gaming/niri/steam-games.kdl`

The core config keeps the portable pieces: transparent Niri background, layout feel, and workspaces `1` through `5`.
Copy only the hardware-specific parts you need into `~/.config/niri/config.kdl`.

## Generated Files

These files may be rewritten at runtime:

| File | Generator |
| --- | --- |
| `~/.config/niri/focus-mode.kdl` | `~/.config/niri/scripts/focus-mode.sh` |
| `~/.config/niri/colors.kdl` | Pywal/Matugen bridge |
| `~/.config/niri/imperative/generated-binds.kdl` | `niri-keybind-generator.py` |
| `~/.config/niri/imperative/generated-scale.kdl` | `niri-scale-generator.sh` |
| `~/.config/quickshell/settings.json` | Quickshell settings panel |

Do not commit runtime cache or state from `~/.cache`, `~/.local/state`, or `$XDG_RUNTIME_DIR`.
